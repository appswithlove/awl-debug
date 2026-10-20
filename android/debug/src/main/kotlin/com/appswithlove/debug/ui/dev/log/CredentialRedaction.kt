package com.appswithlove.debug.ui.dev.log

import okio.ByteString.Companion.decodeBase64

private val BEARER_REGEX = Regex("""\b(Bearer)\s+[A-Za-z0-9\-._~+/]+=*""", RegexOption.IGNORE_CASE)
private val BASIC_REGEX = Regex("""\b(Basic)\s+([A-Za-z0-9+/]+={0,2})""", RegexOption.IGNORE_CASE)

/**
 * Replaces `Bearer <token>` and `Basic <credentials>` with `Bearer [REDACTED]` / `Basic [REDACTED]`.
 * `Basic` is only redacted when it is followed by Base64 of `user:password`, so prose such as
 * "Basic setup" stays readable.
 */
internal fun String.redactCredentials(): String =
    replace(BEARER_REGEX) { "${it.groupValues[1]} [REDACTED]" }
        .replace(BASIC_REGEX) { match ->
            if (match.groupValues[2].isBasicCredentials()) "${match.groupValues[1]} [REDACTED]" else match.value
        }

private fun String.isBasicCredentials(): Boolean = decodeBase64()?.utf8()?.contains(':') == true
