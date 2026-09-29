package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.api.DevNetworkConfig
import okhttp3.MediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.Response
import okio.Buffer
import okio.BufferedSource
import okio.GzipSource
import okio.Sink
import okio.Timeout
import okio.buffer
import java.io.EOFException
import java.io.IOException

/** Reads request and response bodies without consuming them, then redacts and caps them. */
internal class BodyCapture(
    private val config: DevNetworkConfig,
    private val redactor: NetworkRedactor,
) {

    fun request(body: RequestBody?, counter: NetworkRedactor.Counter): CapturedBody? {
        if (body == null) return null
        val contentType = body.contentType()
        if (!config.captureBodies) return placeholder(NOT_CAPTURED, contentType)
        if (body.isOneShot() || body.isDuplex()) return placeholder(ONE_SHOT, contentType)
        return try {
            if (body is MultipartBody) return multipart(body, counter)
            val contentLength = body.contentLength()
            if (contentLength > MAX_READ_BYTES) return placeholder(tooLarge(contentLength), contentType)
            val sink = CappedSink(MAX_READ_BYTES)
            sink.buffer().use { body.writeTo(it) }
            if (sink.totalBytes > MAX_READ_BYTES) return placeholder(tooLarge(sink.totalBytes), contentType)
            fromBytes(sink.captured.readByteArray(), contentType, counter)
        } catch (e: IOException) {
            placeholder("(body could not be read: ${e.message})", contentType)
        }
    }

    fun response(response: Response, counter: NetworkRedactor.Counter): CapturedBody? {
        val body = response.body ?: return null
        val contentType = body.contentType()
        val contentLength = body.contentLength()
        if (response.request.method == "HEAD" || response.code == 204 || response.code == 304 || contentLength == 0L) {
            return null
        }
        if (!config.captureBodies) return placeholder(NOT_CAPTURED, contentType)
        if (response.code == 101 || contentType?.let { "${it.type}/${it.subtype}" } == "text/event-stream") {
            return placeholder(STREAM, contentType)
        }
        if (contentLength > MAX_READ_BYTES) return placeholder(tooLarge(contentLength), contentType)
        val encoding = response.header("Content-Encoding")?.lowercase()
        if (encoding != null && encoding != "identity" && encoding != "gzip") {
            return placeholder("($encoding encoded body, not captured)", contentType)
        }
        return try {
            val raw = response.peekBody(MAX_READ_BYTES + 1).source()
            val bytes = if (encoding == "gzip") GzipSource(raw).buffer().readAtMost(MAX_READ_BYTES + 1) else raw.readByteArray()
            if (bytes.size > MAX_READ_BYTES) {
                val size = contentLength.takeIf { it >= 0 && encoding == null }
                placeholder(size?.let(::tooLarge) ?: "(more than $MAX_READ_BYTES bytes, too large to redact)", contentType)
            } else {
                fromBytes(bytes, contentType, counter)
            }
        } catch (e: IOException) {
            placeholder("(body could not be read: ${e.message})", contentType)
        }
    }

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
        val fieldName = disposition?.let { NAME_REGEX.find(it)?.groupValues?.get(1) }
        if (fieldName != null && redactor.isRedactedField(fieldName)) {
            counter.increment()
            return NetworkRedactor.REDACTED
        }
        val buffer = Buffer()
        partBody.writeTo(buffer)
        return buffer.readUtf8()
    }

    private fun fromBytes(bytes: ByteArray, contentType: MediaType?, counter: NetworkRedactor.Counter): CapturedBody {
        val isText = if (contentType == null) bytes.isProbablyUtf8() else isTextType(contentType)
        if (!isText) return placeholder("(binary, ${bytes.size} bytes)", contentType)
        val text = String(bytes, contentType?.charset() ?: Charsets.UTF_8)
        val redacted = when {
            contentType.isJson() -> redactor.json(text, counter) ?: return placeholder(UNPARSABLE_JSON, contentType)
            contentType.isForm() -> redactor.form(text, counter)
            else -> text
        }
        return cap(redacted, contentType, bytes.size.toLong())
    }

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

    /** Keeps the first [limit] bytes written to it and only counts the rest. */
    private class CappedSink(private val limit: Long) : Sink {
        val captured = Buffer()
        var totalBytes = 0L
            private set

        override fun write(source: Buffer, byteCount: Long) {
            val bytesToKeep = minOf(byteCount, limit + 1 - captured.size).coerceAtLeast(0L)
            source.read(captured, bytesToKeep)
            source.skip(byteCount - bytesToKeep)
            totalBytes += byteCount
        }

        override fun flush() = Unit
        override fun timeout(): Timeout = Timeout.NONE
        override fun close() = Unit
    }

    companion object {
        /** Bodies above this size are not read, because they cannot be redacted cheaply. */
        const val MAX_READ_BYTES: Long = 1024L * 1024

        const val NOT_CAPTURED = "(not captured)"
        const val ONE_SHOT = "(one-shot body, not captured)"
        const val STREAM = "(stream, not captured)"
        const val UNPARSABLE_JSON = "(unparsable JSON, not shown)"

        private val TEXT_APPLICATION_SUBTYPES = setOf("json", "xml", "x-www-form-urlencoded", "graphql")
        private val FILE_NAME_REGEX = Regex("""filename="([^"]*)"""")
        private val NAME_REGEX = Regex("""\bname="([^"]*)"""")

        private fun tooLarge(bytes: Long) = "($bytes bytes, too large to redact)"
    }
}
