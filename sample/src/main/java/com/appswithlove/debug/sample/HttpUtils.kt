package com.appswithlove.debug.sample

import com.appswithlove.debug.sample.BuildConfig
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import com.appswithlove.debug.ui.dev.log.LogCollector.devLogCollector
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import java.io.IOException
import java.util.concurrent.TimeUnit

object HttpUtils {

    val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .addInterceptor(DevHttpLogInterceptor(logCollector = devLogCollector))
        .addInterceptor(
            HttpLoggingInterceptor().apply {
                level = if (BuildConfig.DEBUG) {
                    HttpLoggingInterceptor.Level.BODY
                } else {
                    HttpLoggingInterceptor.Level.NONE
                }
            },
        )
        .build()

    val request = Request.Builder()
        .url("https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current_weather=true")
        .get()
        .build()

    fun sendHttpRequest() {
        okHttpClient.newCall(request).enqueue(object : Callback {

            override fun onFailure(call: Call, e: IOException) {
                e.printStackTrace()
            }

            override fun onResponse(call: Call, response: Response) {
                return
            }
        })
    }
}
