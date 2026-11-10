package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.api.DevNetworkConfig
import okhttp3.MediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.Response
import okhttp3.ResponseBody
import okio.Buffer
import okio.BufferedSource
import okio.ForwardingSource
import okio.GzipSource
import okio.Sink
import okio.Source
import okio.Timeout
import okio.buffer
import java.io.EOFException
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Reads request and response bodies without consuming them, then redacts and caps them. Only reading happens in the
 * request path; redaction runs later, through the returned functions.
 */
internal class BodyCapture(
    private val config: DevNetworkConfig,
    private val redactor: NetworkRedactor,
) {

    private val streamContentTypes = (ALWAYS_STREAM_CONTENT_TYPES + config.streamContentTypes)
        .mapTo(mutableSetOf()) { it.trim().lowercase() }

    /** Reads the body now; the returned function redacts it. */
    fun request(body: RequestBody?, counter: NetworkRedactor.Counter): () -> CapturedBody? {
        if (body == null) return { null }
        val contentType = body.contentType()
        if (!config.captureBodies) return constant(placeholder(NOT_CAPTURED, contentType))
        if (body.isOneShot() || body.isDuplex()) return constant(placeholder(ONE_SHOT, contentType))
        // Reading a body is only safe when writing it twice sends the same bytes and has no side effects.
        if (!body.isOkHttpBody()) return constant(placeholder(CUSTOM_BODY, contentType))
        return try {
            if (body is MultipartBody) return constant(multipart(body, counter))
            val contentLength = body.contentLength()
            if (contentLength > MAX_READ_BYTES) return constant(placeholder(tooLarge(contentLength), contentType))
            val sink = CappedSink(MAX_READ_BYTES)
            try {
                sink.buffer().use { body.writeTo(it) }
            } catch (_: CappedSink.LimitExceeded) {
                return constant(placeholder(MORE_THAN_LIMIT, contentType))
            }
            val bytes = sink.captured.readByteArray()
            return { fromBytes(bytes, contentType, counter) }
        } catch (e: IOException) {
            constant(placeholder("(body could not be read: ${e.message})", contentType))
        }
    }

    /**
     * Decides from the headers whether the response body can be captured. [ResponseCapture.ReadAlong] bodies are
     * never read ahead of the app, which would hold back a streamed response until it ends.
     */
    fun response(response: Response): ResponseCapture {
        val body = response.body ?: return ResponseCapture.Ready(null)
        val contentType = body.contentType()
        val contentLength = body.contentLength()
        if (response.request.method == "HEAD" || response.code == 204 || response.code == 304 || contentLength == 0L) {
            return ResponseCapture.Ready(null)
        }
        if (!config.captureBodies) return ResponseCapture.Ready(placeholder(NOT_CAPTURED, contentType))
        if (response.code == 101 || contentType?.let { "${it.type}/${it.subtype}" } in streamContentTypes) {
            return ResponseCapture.Ready(placeholder(STREAM, contentType))
        }
        if (contentLength > MAX_READ_BYTES) return ResponseCapture.Ready(placeholder(tooLarge(contentLength), contentType))
        if (contentType != null && !isTextType(contentType)) return ResponseCapture.Ready(placeholder(binary(contentLength), contentType))
        val encoding = response.header("Content-Encoding")?.lowercase()
        if (encoding != null && encoding != "identity" && encoding != "gzip") {
            return ResponseCapture.Ready(placeholder("($encoding encoded body, not captured)", contentType))
        }
        return ResponseCapture.ReadAlong
    }

    /** [response]'s body, keeping the first [MAX_READ_BYTES] as the app reads it. [onDone] runs once it was read to the end or closed. */
    fun readAlong(response: Response, onDone: (ReadAlongResult) -> Unit): ResponseBody =
        ReadAlongResponseBody(response.body!!, MAX_READ_BYTES, onDone)

    /** Redacts a body captured by [readAlong]. */
    fun response(response: Response, result: ReadAlongResult, counter: NetworkRedactor.Counter): CapturedBody {
        val contentType = response.body?.contentType()
        if (!result.isComplete) return placeholder(INCOMPLETE, contentType)
        val encoding = response.header("Content-Encoding")?.lowercase()
        if (result.exceededLimit) {
            val size = result.totalBytes.takeIf { encoding == null }
            return placeholder(size?.let(::tooLarge) ?: MORE_THAN_LIMIT, contentType)
        }
        return try {
            val bytes = if (encoding == "gzip") GzipSource(Buffer().write(result.bytes)).buffer().readAtMost(MAX_READ_BYTES + 1) else result.bytes
            if (bytes.size > MAX_READ_BYTES) placeholder(MORE_THAN_LIMIT, contentType) else fromBytes(bytes, contentType, counter)
        } catch (e: IOException) {
            placeholder("(body could not be read: ${e.message})", contentType)
        }
    }

    private fun constant(body: CapturedBody?): () -> CapturedBody? = { body }

    private fun multipart(body: MultipartBody, counter: NetworkRedactor.Counter): CapturedBody {
        val text = buildString {
            body.parts.forEach { part ->
                append("--").append(body.boundary).append('\n')
                val disposition = part.headers?.get("Content-Disposition")
                disposition?.let { append("Content-Disposition: ").append(it).append('\n') }
                append('\n')
                append(multipartPartText(part, disposition, counter)).append('\n')
            }
            append("--").append(body.boundary).append("--")
        }
        return cap(text, body.contentType(), text.toByteArray().size.toLong())
    }

    private fun multipartPartText(part: MultipartBody.Part, disposition: String?, counter: NetworkRedactor.Counter): String {
        val partBody = part.body
        val fileName = disposition?.let { FILE_NAME_REGEX.find(it)?.groupValues?.get(1) }
        val size = partBody.contentLength()
        // Parts without a content type are text/plain by definition (RFC 7578).
        val isText = partBody.contentType()?.let(::isTextType) ?: true
        if (fileName != null || !isText || size !in 0..MAX_READ_BYTES) {
            return "(file ${fileName ?: "unnamed"}, $size bytes)"
        }
        if (!partBody.isOkHttpBody()) return CUSTOM_BODY
        val fieldName = disposition?.let { NAME_REGEX.find(it)?.groupValues?.get(1) }
        if (fieldName != null && redactor.isRedactedField(fieldName)) {
            counter.increment()
            return NetworkRedactor.REDACTED
        }
        val buffer = Buffer()
        partBody.writeTo(buffer)
        val contentType = partBody.contentType()
        return redact(buffer.readString(contentType?.charset() ?: Charsets.UTF_8), contentType, counter) ?: UNPARSABLE_JSON
    }

    private fun fromBytes(bytes: ByteArray, contentType: MediaType?, counter: NetworkRedactor.Counter): CapturedBody {
        val isText = if (contentType == null) bytes.isProbablyUtf8() else isTextType(contentType)
        if (!isText) return placeholder(binary(bytes.size.toLong()), contentType)
        val text = String(bytes, contentType?.charset() ?: Charsets.UTF_8)
        val redacted = redact(text, contentType, counter) ?: return placeholder(UNPARSABLE_JSON, contentType)
        return cap(redacted, contentType, bytes.size.toLong())
    }

    /** Redacts a text body by its content type; `null` for JSON that cannot be parsed. */
    private fun redact(text: String, contentType: MediaType?, counter: NetworkRedactor.Counter): String? = when {
        contentType.isJson() -> redactor.json(text, counter)
        contentType.isForm() -> redactor.form(text, counter)
        else -> redactor.text(text, counter)
    }

    /** Bodies OkHttp creates itself (`toRequestBody`, `asRequestBody`, `FormBody`, `MultipartBody`) can be written repeatedly. */
    private fun RequestBody.isOkHttpBody() = javaClass.name.startsWith("okhttp3.")

    private fun cap(text: String, contentType: MediaType?, originalBytes: Long): CapturedBody {
        val encoded = text.toByteArray(Charsets.UTF_8)
        if (encoded.size <= config.maxBodyBytes) {
            return CapturedBody(text, contentType?.toString(), originalBytes = originalBytes)
        }
        val truncatedText = String(encoded, 0, config.maxBodyBytes, Charsets.UTF_8).trimEnd('�')
        return CapturedBody(truncatedText, contentType?.toString(), truncated = true, originalBytes = originalBytes)
    }

    private fun placeholder(text: String, contentType: MediaType?) =
        CapturedBody(text, contentType?.toString(), isContent = false)

    private fun isTextType(contentType: MediaType?): Boolean {
        if (contentType == null) return false
        if (contentType.type == "text") return true
        if (contentType.type != "application") return false
        val subtype = contentType.subtype
        return subtype in TEXT_APPLICATION_SUBTYPES || subtype.endsWith("+json") || subtype.endsWith("+xml")
    }

    private fun MediaType?.isJson() = this != null && (subtype == "json" || subtype.endsWith("+json"))

    private fun MediaType?.isForm() = this != null && subtype == "x-www-form-urlencoded"

    private fun BufferedSource.readAtMost(limit: Long): ByteArray {
        val buffer = Buffer()
        try {
            while (buffer.size <= limit && read(buffer, 8_192) != -1L) Unit
        } catch (_: EOFException) {
            // Truncated gzip stream: keep what was decoded.
        }
        return buffer.readByteArray()
    }

    private fun ByteArray.isProbablyUtf8(): Boolean {
        val sample = Buffer().write(this, 0, minOf(size, 64))
        while (!sample.exhausted()) {
            val codePoint = sample.readUtf8CodePoint()
            if (Character.isISOControl(codePoint) && !Character.isWhitespace(codePoint)) return false
        }
        return true
    }

    /** Keeps what is written to it and stops the writer with [LimitExceeded] after [limit] bytes. */
    private class CappedSink(private val limit: Long) : Sink {
        class LimitExceeded : IOException()

        val captured = Buffer()

        override fun write(source: Buffer, byteCount: Long) {
            if (captured.size + byteCount > limit) {
                source.skip(byteCount)
                throw LimitExceeded()
            }
            source.read(captured, byteCount)
        }

        override fun flush() = Unit
        override fun timeout(): Timeout = Timeout.NONE
        override fun close() = Unit
    }

    /** Copies the first [limit] bytes the app reads into memory and drops them once the body is longer. */
    private class ReadAlongResponseBody(
        private val delegate: ResponseBody,
        private val limit: Long,
        private val onDone: (ReadAlongResult) -> Unit,
    ) : ResponseBody() {
        private val source = ReadAlongSource(delegate.source()).buffer()

        override fun contentType(): MediaType? = delegate.contentType()
        override fun contentLength(): Long = delegate.contentLength()
        override fun source(): BufferedSource = source

        private inner class ReadAlongSource(upstream: Source) : ForwardingSource(upstream) {
            /** Guards the capture state; the app may close the body on another thread than it reads it. */
            private val lock = Any()
            private val captured = Buffer()
            private var totalBytes = 0L
            private var exceededLimit = false
            private val isDone = AtomicBoolean(false)

            override fun read(sink: Buffer, byteCount: Long): Long {
                val read = try {
                    super.read(sink, byteCount)
                } catch (e: IOException) {
                    finish(isComplete = false, error = e)
                    throw e
                }
                if (read == -1L) {
                    finish(isComplete = true)
                    return read
                }
                capture(sink, read)
                return read
            }

            /** Never lets the capture keep the app's response open: the connection is released in any case. */
            override fun close() {
                try {
                    if (!isDone.get()) finish(isComplete = isReadToEnd() || drainsToEnd())
                } finally {
                    super.close()
                }
            }

            private fun isReadToEnd(): Boolean {
                val contentLength = this@ReadAlongResponseBody.delegate.contentLength()
                return contentLength >= 0 && synchronized(lock) { totalBytes >= contentLength }
            }

            /**
             * Parsers often stop after the last value, before a chunked or gzip body reports its end. Like OkHttp when it
             * releases a connection, read for a short time what is left; a stream the app closed early stays incomplete.
             */
            private fun drainsToEnd(): Boolean {
                val timeout = delegate.timeout()
                val startNanos = System.nanoTime()
                val remainingNanos = if (timeout.hasDeadline()) timeout.deadlineNanoTime() - startNanos else Long.MAX_VALUE
                timeout.deadlineNanoTime(startNanos + minOf(remainingNanos, DRAIN_TIMEOUT_NANOS))
                return try {
                    val buffer = Buffer()
                    while (synchronized(lock) { !exceededLimit }) {
                        val read = delegate.read(buffer, DRAIN_CHUNK_BYTES)
                        if (read == -1L) return true
                        capture(buffer, read)
                        buffer.clear()
                    }
                    false
                } catch (_: IOException) {
                    false
                } finally {
                    if (remainingNanos == Long.MAX_VALUE) timeout.clearDeadline() else timeout.deadlineNanoTime(startNanos + remainingNanos)
                }
            }

            /** Copies the last [read] bytes of [sink]. */
            private fun capture(sink: Buffer, read: Long) = synchronized(lock) {
                totalBytes += read
                if (!exceededLimit && captured.size + read > limit) {
                    exceededLimit = true
                    captured.clear()
                } else if (!exceededLimit) {
                    sink.copyTo(captured, sink.size - read, read)
                }
            }

            private fun finish(isComplete: Boolean, error: IOException? = null) {
                if (!isDone.compareAndSet(false, true)) return
                val result = synchronized(lock) { ReadAlongResult(captured.readByteArray(), totalBytes, isComplete, exceededLimit, error) }
                // The app's read or close must never fail because of the capture.
                runCatching { onDone(result) }
            }
        }
    }

    companion object {
        /** Bodies above this size are not read, because they cannot be redacted cheaply. */
        const val MAX_READ_BYTES: Long = 1024L * 1024

        const val NOT_CAPTURED = "(not captured)"
        const val ONE_SHOT = "(one-shot body, not captured)"
        const val STREAM = "(stream, not captured)"
        const val UNPARSABLE_JSON = "(unparsable JSON, not shown)"
        const val INCOMPLETE = "(not read to the end, not captured)"
        const val CUSTOM_BODY = "(custom request body, not captured)"
        private const val MORE_THAN_LIMIT = "(more than $MAX_READ_BYTES bytes, too large to redact)"
        private val DRAIN_TIMEOUT_NANOS = TimeUnit.MILLISECONDS.toNanos(100)
        private const val DRAIN_CHUNK_BYTES = 8_192L

        private val ALWAYS_STREAM_CONTENT_TYPES = setOf("text/event-stream", "application/x-ndjson")
        private val TEXT_APPLICATION_SUBTYPES = setOf("json", "xml", "x-www-form-urlencoded", "graphql")
        private val FILE_NAME_REGEX = Regex("""filename="([^"]*)"""")
        private val NAME_REGEX = Regex("""\bname="([^"]*)"""")

        private fun tooLarge(bytes: Long) = "($bytes bytes, too large to redact)"

        private fun binary(bytes: Long) = if (bytes >= 0) "(binary, $bytes bytes)" else "(binary, not captured)"
    }
}

internal sealed interface ResponseCapture {
    /** Known from the headers, without reading the body. */
    data class Ready(val body: CapturedBody?) : ResponseCapture

    /** Captured while the app reads the body, see [BodyCapture.readAlong]. */
    data object ReadAlong : ResponseCapture
}

internal class ReadAlongResult(
    /** Empty when [exceededLimit]. */
    val bytes: ByteArray,
    val totalBytes: Long,
    /** `false` when the app closed the body before its end or reading it failed. */
    val isComplete: Boolean,
    val exceededLimit: Boolean,
    /** Why reading the body failed. */
    val error: IOException? = null,
)
