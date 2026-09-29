package com.appswithlove.debug.feedback

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

private const val PREFERENCES_NAME = "awl_debug_feedback"
private const val KEY_NAME = "reporter_name"
private const val KEY_EMAIL = "reporter_email"

/** Name and email the tester entered, kept on the device so later reports need no prompt. */
internal class ReporterStore(private val preferences: SharedPreferences) {

    constructor(context: Context) : this(context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE))

    /** The saved reporter, or [fallback] (the app's [FeedbackConfig.reporter]) until the tester entered one. */
    fun load(fallback: FeedbackReporter?): FeedbackReporter? {
        val name = preferences.getString(KEY_NAME, null)?.takeIf { it.isNotBlank() }
            ?: return fallback?.takeIf { it.name.isNotBlank() }
        return FeedbackReporter(name = name, email = preferences.getString(KEY_EMAIL, null))
    }

    fun save(reporter: FeedbackReporter) {
        preferences.edit {
            putString(KEY_NAME, reporter.name.trim())
            putString(KEY_EMAIL, reporter.email?.trim()?.takeIf { it.isNotEmpty() })
        }
    }
}
