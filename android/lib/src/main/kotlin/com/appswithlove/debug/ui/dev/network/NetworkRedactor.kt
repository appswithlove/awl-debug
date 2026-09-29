package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.api.DevNetworkConfig
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okhttp3.Headers
import okhttp3.HttpUrl
import java.net.URLDecoder

/** Replaces sensitive values in headers, URLs and bodies before anything is stored. */
internal class NetworkRedactor(config: DevNetworkConfig) {

    /** Counts redacted values for one request. */
    class Counter {
        var count: Int = 0
            private set

        fun increment() {
            count++
        }
    }

    private val headerNames = (ALWAYS_REDACTED_HEADERS + config.redactHeaders).mapTo(mutableSetOf()) { it.lowercase() }
    private val fieldNames = config.redactJsonFields.mapTo(mutableSetOf(), ::normalizeFieldName)
    private val queryNames = config.redactQueryParams.mapTo(mutableSetOf()) { it.lowercase() }

    fun headers(headers: Headers, counter: Counter): List<Pair<String, String>> =
        headers.map { (name, value) ->
            if (name.lowercase() in headerNames) {
                counter.increment()
                name to REDACTED
            } else {
                name to value
            }
        }

    fun url(url: HttpUrl, counter: Counter): String {
        val schemePrefix = "${url.scheme}://"
        var base = url.toString().substringBefore('?').substringBefore('#')
        if (url.username.isNotEmpty() || url.password.isNotEmpty()) {
            counter.increment()
            base = schemePrefix + REDACTED + base.substring(base.indexOf('@', schemePrefix.length))
        }
        val query = url.encodedQuery?.let { "?" + redactPairs(it, counter) { name -> name.lowercase() in queryNames } }
        val fragment = url.encodedFragment?.let { "#$it" }
        return base + query.orEmpty() + fragment.orEmpty()
    }

    fun isRedactedField(name: String): Boolean = normalizeFieldName(name) in fieldNames

    /** Returns the redacted JSON in compact form, or `null` when [text] is not valid JSON. */
    fun json(text: String, counter: Counter): String? {
        val element = try {
            Json.parseToJsonElement(text)
        } catch (_: SerializationException) {
            return null
        } catch (_: IllegalArgumentException) {
            return null
        }
        return redactJson(element, counter).toString()
    }

    fun form(text: String, counter: Counter): String = redactPairs(text, counter, ::isRedactedField)

    private fun redactJson(element: JsonElement, counter: Counter): JsonElement = when (element) {
        is JsonObject -> JsonObject(
            element.mapValues { (key, value) ->
                if (isRedactedField(key)) {
                    counter.increment()
                    JsonPrimitive(REDACTED)
                } else {
                    redactJson(value, counter)
                }
            }
        )

        is JsonArray -> JsonArray(element.map { redactJson(it, counter) })
        else -> element
    }

    /** Redacts values in `name=value&name=value` while keeping the encoding of everything else. */
    private fun redactPairs(encoded: String, counter: Counter, shouldRedact: (String) -> Boolean): String =
        encoded.split('&').joinToString("&") { pair ->
            val encodedName = pair.substringBefore('=')
            if ('=' in pair && shouldRedact(decode(encodedName))) {
                counter.increment()
                "$encodedName=$REDACTED"
            } else {
                pair
            }
        }

    private fun decode(value: String): String = try {
        URLDecoder.decode(value, Charsets.UTF_8.name())
    } catch (_: IllegalArgumentException) {
        value
    }

    companion object {
        const val REDACTED = "[REDACTED]"
        private val ALWAYS_REDACTED_HEADERS = setOf("Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie")

        private fun normalizeFieldName(name: String): String =
            name.lowercase().replace("_", "").replace("-", "")
    }
}
