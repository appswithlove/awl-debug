package com.appswithlove.debug.api

/** Example usage:
```
import com.appswithlove.yourapp.BuildConfig

val devConfigs = DevConfigs(
versionName = BuildConfig.VERSION_NAME,
versionCode = BuildConfig.VERSION_CODE,
flavor = BuildConfig.FLAVOR,
buildType = BuildConfig.BUILD_TYPE,
customParams = mapOf("Server" to BuildConfig.BASE_URL),
)
```
 */
data class DevConfig(
    val versionName: String,
    val versionCode: Int,
    val flavor: String,
    val buildType: String,
    val customParams: Map<String, String> = emptyMap(),
) {
    companion object {
        val Preview = DevConfig(
            versionName = "1.0",
            versionCode = 1254621,
            flavor = "Prod",
            buildType = "Release",
            customParams = mapOf("Server" to "https://api.example.com"),
        )
    }
}
