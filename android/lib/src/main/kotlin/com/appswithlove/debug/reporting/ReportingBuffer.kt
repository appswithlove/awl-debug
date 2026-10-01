package com.appswithlove.debug.reporting

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.zip.GZIPOutputStream

/**
 * File buffer for remote reporting, one folder per session:
 *
 * ```
 * <root>/sessions/<sessionId>/session.json   session object and bookkeeping
 * <root>/sessions/<sessionId>/entries.txt    one entry per line, not yet in a batch
 * <root>/batches/<seq>_<sessionId>_<n>.json.gz  sealed batches, oldest first, fixed bytes
 * ```
 *
 * Everything together stays below [maxBytes]; the oldest entries are dropped first and counted in
 * `droppedCount`. Not thread-safe: the caller runs all calls on one thread.
 */
internal class ReportingBuffer(
    private val root: File,
    private val maxBytes: Long = MAX_BYTES,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private class Record(
        var session: ReportingSession,
        /** `endedAt` of the last sealed batch, to seal a batch when only `endedAt` changed. */
        var sealedEndedAtMillis: Long? = null,
        var lastEntryMillis: Long? = null,
        var droppedCount: Long = 0,
    )

    private val sessionsDir = File(root, "sessions")
    private val batchesDir = File(root, "batches")
    private val records = LinkedHashMap<String, Record>()
    private var totalBytes = 0L
    private var nextSeq = 0L

    /** Sessions left over from an earlier process, oldest first. */
    fun load(): List<ReportingSession> {
        records.clear()
        sessionsDir.listFiles()?.forEach { dir ->
            val record = readRecord(dir)
            if (record == null) dir.deleteRecursively() else records[record.session.id] = record
        }
        nextSeq = sealedBatches().maxOfOrNull { it.name.substringBefore('_').toLongOrNull() ?: 0L }?.plus(1) ?: 0L
        totalBytes = root.walkTopDown().filter { it.isFile }.sumOf { it.length() }
        return records.values.map { it.session }.sortedBy { it.startedAtMillis }
    }

    val sizeBytes: Long get() = totalBytes

    fun droppedCount(sessionId: String): Long = records[sessionId]?.droppedCount ?: 0

    fun putSession(session: ReportingSession) {
        val record = records.getOrPut(session.id) { Record(session) }
        record.session = session
        writeRecord(record)
    }

    fun append(sessionId: String, timestampMillis: Long, kind: EntryKind, json: JsonObject) {
        val record = records[sessionId] ?: return
        val line = "${kind.prefix}$timestampMillis\t$json\n".toByteArray(Charsets.UTF_8)
        FileOutputStream(entriesFile(sessionId), true).use { it.write(line) }
        totalBytes += line.size
        record.lastEntryMillis = maxOf(record.lastEntryMillis ?: timestampMillis, timestampMillis)
        if (totalBytes > maxBytes) trim()
    }

    /**
     * Moves the pending entries of [sessionId] into sealed batches. With [finish] the session is
     * done: a missing `endedAt` becomes the time of its last entry and its folder is removed.
     */
    fun seal(sessionId: String, finish: Boolean = false): List<File> {
        val record = records[sessionId] ?: return emptyList()
        val entries = readEntries(sessionId)
        val endedAt = record.session.endedAtMillis
            ?: if (finish) entries.lastOrNull()?.timestampMillis ?: record.lastEntryMillis ?: record.session.startedAtMillis else null
        val session = record.session.copy(endedAtMillis = endedAt)
        val needsBatch = entries.isNotEmpty() || record.droppedCount > 0 || (endedAt != null && endedAt != record.sealedEndedAtMillis)
        val written = if (needsBatch) writeBatches(session, entries, record.droppedCount) else emptyList()
        record.droppedCount = 0
        record.sealedEndedAtMillis = endedAt
        entries.lastOrNull()?.let { record.lastEntryMillis = maxOf(record.lastEntryMillis ?: 0L, it.timestampMillis) }
        val entriesFile = entriesFile(sessionId)
        totalBytes -= entriesFile.length()
        entriesFile.delete()
        if (finish) {
            totalBytes -= sessionDir(sessionId).walkTopDown().filter { it.isFile }.sumOf { it.length() }
            sessionDir(sessionId).deleteRecursively()
            records.remove(sessionId)
        } else {
            writeRecord(record)
        }
        if (totalBytes > maxBytes) trim()
        return written
    }

    /** Sealed batches, oldest first. Each file is a gzip-compressed batch ready to send. */
    fun sealedBatches(): List<File> = batchesDir.listFiles { file -> file.name.endsWith(BATCH_SUFFIX) }
        ?.sortedBy { it.name }
        .orEmpty()

    /** Removes a batch once the service has accepted or rejected it for good. */
    fun deleteBatch(batch: File) {
        val size = batch.length()
        if (batch.delete()) totalBytes -= size
    }

    private fun writeBatches(session: ReportingSession, entries: List<Entry>, droppedCount: Long): List<File> {
        val chunks = mutableListOf<List<Entry>>()
        var chunk = mutableListOf<Entry>()
        var logs = 0
        var metrics = 0
        var rawBytes = 0L
        entries.forEach { entry ->
            val full = when (entry.kind) {
                EntryKind.Network -> logs >= MAX_ENTRIES
                EntryKind.Metric -> metrics >= MAX_ENTRIES
            }
            if (full || rawBytes + entry.json.length > MAX_RAW_CHUNK_BYTES) {
                chunks += chunk
                chunk = mutableListOf()
                logs = 0
                metrics = 0
                rawBytes = 0
            }
            chunk += entry
            if (entry.kind == EntryKind.Network) logs++ else metrics++
            rawBytes += entry.json.length
        }
        chunks += chunk
        var dropped = droppedCount
        return chunks.filter { it.isNotEmpty() || chunks.size == 1 }.flatMap { entriesOfBatch ->
            writeBatch(session, entriesOfBatch, dropped).also { dropped = 0 }
        }
    }

    /** Writes one batch, split in halves while it is larger than [MAX_BATCH_GZIP_BYTES]. */
    private fun writeBatch(session: ReportingSession, entries: List<Entry>, droppedCount: Long): List<File> {
        val batchId = UUID.randomUUID().toString()
        val gzipped = gzip(batchJson(batchId, session, entries, droppedCount))
        if (gzipped.size > MAX_BATCH_GZIP_BYTES && entries.size > 1) {
            val half = entries.size / 2
            return writeBatch(session, entries.subList(0, half), droppedCount) +
                writeBatch(session, entries.subList(half, entries.size), 0)
        }
        if (gzipped.size > MAX_BATCH_GZIP_BYTES) {
            // A single entry cannot get this large with the body cap; drop it rather than block the queue.
            records[session.id]?.let { it.droppedCount += entries.size }
            return emptyList()
        }
        batchesDir.mkdirs()
        val file = File(batchesDir, "%016d_%s_%d%s".format(nextSeq++, session.id, entries.size, BATCH_SUFFIX))
        val tmp = File(batchesDir, file.name + ".tmp")
        tmp.writeBytes(gzipped)
        tmp.renameTo(file)
        totalBytes += gzipped.size
        return listOf(file)
    }

    private fun batchJson(batchId: String, session: ReportingSession, entries: List<Entry>, droppedCount: Long): String =
        buildString {
            append("{\"batchId\":\"").append(batchId).append('"')
            append(",\"sentAt\":\"").append(ReportingJson.timestamp(clock())).append('"')
            append(",\"session\":").append(ReportingJson.session(session))
            appendArray("networkLogs", entries.filter { it.kind == EntryKind.Network })
            appendArray("metrics", entries.filter { it.kind == EntryKind.Metric })
            if (droppedCount > 0) append(",\"droppedCount\":").append(droppedCount)
            append('}')
        }

    private fun StringBuilder.appendArray(name: String, entries: List<Entry>) {
        if (entries.isEmpty()) return
        append(",\"").append(name).append("\":[")
        entries.forEachIndexed { index, entry ->
            if (index > 0) append(',')
            append(entry.json)
        }
        append(']')
    }

    /** Drops the oldest data, sealed batches first, until the buffer is back below 90 % of [maxBytes]. */
    private fun trim() {
        val target = maxBytes * 9 / 10
        while (totalBytes > target) {
            val oldestBatch = sealedBatches().firstOrNull()
            if (oldestBatch != null) {
                val parts = oldestBatch.name.removeSuffix(BATCH_SUFFIX).split('_')
                val count = parts.getOrNull(2)?.toLongOrNull() ?: 0L
                val owner = parts.getOrNull(1)?.let { records[it] } ?: records.values.maxByOrNull { it.session.startedAtMillis }
                owner?.let { it.droppedCount += count; writeRecord(it) }
                deleteBatch(oldestBatch)
                continue
            }
            val record = records.values.sortedBy { it.session.startedAtMillis }
                .firstOrNull { entriesFile(it.session.id).length() > 0 } ?: return
            val file = entriesFile(record.session.id)
            val lines = file.readLines().filter { it.isNotEmpty() }
            var excess = totalBytes - target
            var drop = 0
            while (drop < lines.size && excess > 0) {
                excess -= lines[drop].toByteArray(Charsets.UTF_8).size + 1
                drop++
            }
            val before = file.length()
            file.writeText(lines.drop(drop).joinToString("") { "$it\n" })
            totalBytes -= before - file.length()
            record.droppedCount += drop
            writeRecord(record)
        }
    }

    private fun readEntries(sessionId: String): List<Entry> {
        val file = entriesFile(sessionId)
        if (!file.exists()) return emptyList()
        return file.readLines().mapNotNull { line ->
            val kind = EntryKind.entries.firstOrNull { line.startsWith(it.prefix) } ?: return@mapNotNull null
            val tab = line.indexOf('\t')
            val millis = line.substring(1, tab.coerceAtLeast(1)).toLongOrNull() ?: return@mapNotNull null
            // A line cut off by a crash is not valid JSON; skip it.
            if (!line.endsWith("}")) return@mapNotNull null
            Entry(kind, millis, line.substring(tab + 1))
        }
    }

    private fun writeRecord(record: Record) {
        val dir = sessionDir(record.session.id).apply { mkdirs() }
        val json = buildJsonObject {
            record.session.toStoredJson().forEach { (key, value) -> put(key, value) }
            record.sealedEndedAtMillis?.let { put("sealedEndedAtMillis", it) }
            record.lastEntryMillis?.let { put("lastEntryMillis", it) }
            put("droppedCount", record.droppedCount)
        }.toString().toByteArray(Charsets.UTF_8)
        val file = File(dir, SESSION_FILE)
        val tmp = File(dir, "$SESSION_FILE.tmp")
        totalBytes -= file.length()
        tmp.writeBytes(json)
        tmp.renameTo(file)
        totalBytes += json.size
    }

    private fun readRecord(dir: File): Record? = try {
        val json = Json.parseToJsonElement(File(dir, SESSION_FILE).readText()) as JsonObject
        val session = ReportingSession.fromStoredJson(json)
        session?.let {
            Record(
                session = it,
                sealedEndedAtMillis = json.long("sealedEndedAtMillis"),
                lastEntryMillis = json.long("lastEntryMillis"),
                droppedCount = json.long("droppedCount") ?: 0,
            )
        }
    } catch (_: Exception) {
        null
    }

    private fun JsonObject.long(key: String): Long? = (this[key] as? JsonPrimitive)?.jsonPrimitive?.longOrNull

    private fun sessionDir(sessionId: String) = File(sessionsDir, sessionId)

    private fun entriesFile(sessionId: String) = File(sessionDir(sessionId), ENTRIES_FILE)

    private fun gzip(text: String): ByteArray = ByteArrayOutputStream().also { out ->
        GZIPOutputStream(out).use { it.write(text.toByteArray(Charsets.UTF_8)) }
    }.toByteArray()

    private class Entry(val kind: EntryKind, val timestampMillis: Long, val json: String)

    enum class EntryKind(val prefix: Char) { Network('n'), Metric('m') }

    companion object {
        const val MAX_BYTES = 10L * 1024 * 1024
        const val MAX_ENTRIES = 2000
        const val MAX_BATCH_GZIP_BYTES = 1024 * 1024
        private const val MAX_RAW_CHUNK_BYTES = 8L * 1024 * 1024
        private const val SESSION_FILE = "session.json"
        private const val ENTRIES_FILE = "entries.txt"
        const val BATCH_SUFFIX = ".json.gz"
    }
}
