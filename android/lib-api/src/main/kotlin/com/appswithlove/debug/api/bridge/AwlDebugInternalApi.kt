package com.appswithlove.debug.api.bridge

/** Connects the awl-debug artifacts with each other. Not meant for app code and may change in any release. */
@RequiresOptIn(message = "Internal bridge between awl-debug artifacts. Do not use it from app code.")
@Retention(AnnotationRetention.BINARY)
@Target(AnnotationTarget.CLASS, AnnotationTarget.PROPERTY, AnnotationTarget.FUNCTION)
annotation class AwlDebugInternalApi
