package com.appswithlove.debug.sample

import android.app.Application

class SampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DemoExtension.register(this)
    }
}
