package com.appswithlove.debug.example

import android.app.Application

class ExampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DemoExtension.register(this)
    }
}
