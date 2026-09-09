# awl-debug 🚧

Library for debugging and logging of Android apps.

🚧Work in progress 🚧

Made by [Apps with love](https://appswithlove.com). Licensed under [Apache 2.0](LICENSE).

### Contributors

- Vladislav Frolov
- Michel Utke
- Yannick Pulver

### Features

- [x] Open and close DevSheet by three finger tap
- [x] Logs: filter by query, export to file (Timber + HTTP integration)
- [x] Deeplinks: fire deeplinks from the sheet
- [x] Session: inspect / edit / delete auth tokens
- [x] Permissions, Performance and Accessibility modules
- [x] Test crashes
- [x] FCM push token: display, refresh and revoke (you provide the source)
- [x] Custom modules can be added

# ⛺️ Setup

1. add the following dependencies to your project's `build.gradle` file:

```
// full debug panel in debug builds, inert no-op in release builds
debugImplementation("com.appswithlove.debug:debug:0.6.0")
releaseImplementation("com.appswithlove.debug:debug-no-op:0.6.0")
```

Both artifacts expose the same public API (`DevSheet`, `DevConfig`, `DevModulesConfig`,
`SessionProvider`, `DevLogTree`, `DevHttpLogInterceptor`, …) via the shared
`com.appswithlove.debug:debug-api` artifact, so the same call sites compile against either.
The `debug-no-op` variant strips all debug UI, gesture detection and log collection from
release builds — `DevSheet` simply renders your content.

> The config/contract types now live under `com.appswithlove.debug.api.*`
> (e.g. `com.appswithlove.debug.api.DevConfig`, `com.appswithlove.debug.api.session.SessionProvider`).

2. make sure `mavenCentral()` is in your repositories (default in new Android projects):

```
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

All artifacts are published to [Maven Central](https://central.sonatype.com/namespace/com.appswithlove.debug). No token or extra repository needed.

# 🧪 Testing the library locally

To test this library in another project before publishing it to a remote repository, you can publish it to your local Maven repository:

```
./gradlew publishToMavenLocal -PRELEASE_SIGNING_ENABLED=false
```

`-PRELEASE_SIGNING_ENABLED=false` skips GPG signing, which is only required for Maven Central releases.

This command installs the library into your local Maven repository, usually located at:

```~/.m2/repository/```

Then, in the project where you want to test the library, update your repositories block to include `mavenLocal()` before other repositories:

```
repositories {
    mavenLocal()
    mavenCentral()
    google()
}
```


Finally, add the library dependency using the same coordinates defined in your build.gradle:

```
dependencies {
    implementation("com.appswithlove.debug:debug:0.6.0")
}
```

Now you can build and run your project using the locally published version of the library.

# 🚀 Usage

## 🛠 DevSheet

Wrap `DevSheet` around your top-level composable. The sheet opens with a **three-finger tap**.

```kotlin
DevSheet(
    devConfig = DevConfig(
        versionName = BuildConfig.VERSION_NAME,
        versionCode = BuildConfig.VERSION_CODE,
        flavor = BuildConfig.FLAVOR,
        buildType = BuildConfig.BUILD_TYPE,
    ),
) {
    // your screen content
    MyApp()
}
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `devConfig` | `null` | App build info displayed in the sheet (version, flavor, build type) |
| `logHistory` | `LogCollector.logHistory` | Log history to display; override to use a custom instance |
| `modulesConfig` | `DevModulesConfig()` | Controls which built-in modules are shown; all enabled by default |
| `isAlwaysActive` | `false` | When `true`, the three-finger tap gesture works even if the dev tool is toggled off |
| `swipeToDismiss` | `false` | When `true`, the sheet can be dismissed by swiping down |
| `customModules` | — | Composable lambda to append your own modules at the bottom of the sheet |

### Disabling modules

Pass a `DevModulesConfig` to hide specific built-in modules:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        showPerformanceModule = false,
        showAccessibilityModule = false,
    )
) {
    MyApp()
}
```

## 🔗 Deeplinks

The Deeplinks module lets you fire deeplinks directly from the debug sheet — useful for testing navigation during development.

- Enter or paste a deeplink URL and tap **Shoot** to launch it
- Optionally pre-configure a list of deeplinks for one-tap access

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        deeplinks = listOf(
            DeeplinkItem(label = "Home", url = "myapp://home"),
            DeeplinkItem(label = "Profile", url = "myapp://profile/123"),
        )
    )
) {
    MyApp()
}
```

## 🔐 Session

The Session module lets you inspect and manipulate the current auth state directly from the debug sheet.

**Features:**
- Shows logged in / logged out status per provider
- Copy the current access token to clipboard
- Edit the token (e.g. paste invalid token to trigger a refresh) — only when `onSetToken` is provided
- Delete the token to break the session — only when `onSetToken` is provided

Implement `SessionProvider` for each token source in your app and pass the list to `DevModulesConfig`:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        sessionProviders = listOf(
            object : SessionProvider {
                override val label = "Auth Token"
                override val token: Flow<String?> = authStorage.tokenFlow

                // Optional — omit to hide the Edit/Delete buttons
                override val onSetToken: suspend (String?) -> Unit = { authStorage.setToken(it) }
            }
        )
    )
) {
    MyApp()
}
```

`tokenFlow` must emit whenever the token changes (login, logout, refresh) - this is how the module stays in sync without manual refreshes.

Multiple providers are supported — each is shown as a separate entry:

```kotlin
sessionProviders = listOf(
    object : SessionProvider {
        override val label = "Auth Token"
        override val token: Flow<String?> = authStorage.tokenFlow
        override val onSetToken: suspend (String?) -> Unit = { authStorage.setToken(it) }
    },
    object : SessionProvider {
        override val label = "Refresh Token"
        override val token: Flow<String?> = authStorage.refreshTokenFlow
        override val onSetToken: suspend (String?) -> Unit = { authStorage.setRefreshToken(it) }
    },
)
```

The module is hidden automatically when `sessionProviders` is empty.

## 📲 FCM Push Token

The FCM module displays the current push token and, optionally, lets you refresh or revoke it. The library has **no Firebase dependency** — you supply the token and the actions via `FcmTokenProvider`:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        fcmTokenProvider = object : FcmTokenProvider {
            override val token: Flow<String?> = fcmStorage.tokenFlow

            // Optional — omit to hide the button
            override val onRefresh: suspend () -> Unit = {
                FirebaseMessaging.getInstance().deleteToken().await()
                fcmStorage.set(FirebaseMessaging.getInstance().token.await())
            }

            // Optional — omit to hide the button
            override val onRevoke: suspend () -> Unit = {
                FirebaseMessaging.getInstance().deleteToken().await()
                fcmStorage.set(null)
            }
        }
    )
) {
    MyApp()
}
```

- `token` must emit whenever the token changes — this keeps the displayed value in sync (e.g. after a refresh).
- `onRefresh` / `onRevoke` default to `null`; each button only appears when its action is provided.
- The module is hidden automatically when `fcmTokenProvider` is `null`.

## 🛠️ Custom modules

```kotlin
DevSheet(
    customModules = {
        Text("My custom debug info")
    }
) {
    MyApp()
}
```

## 🌐 HTTP logging

To capture HTTP traffic in DevTool, add `DevHttpLogInterceptor` to your `OkHttpClient`:

```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor(DevHttpLogInterceptor())
    .build()
```

It logs all requests and responses.

## 🪵 Timber integration

To forward Timber logs to the debug panel, plant `DevLogTree` in your `Application.onCreate()`:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(DevLogTree())
    }
}
```

`DevLogTree` only logs to the debug panel. To also log to logcat, plant `Timber.DebugTree()` alongside it:

```kotlin
Timber.plant(Timber.DebugTree(), DevLogTree())
```

## 🔘 Activate / deactivate devTool

The three-finger tap only opens the sheet while the dev tool is activated (or `isAlwaysActive = true`). Toggle it programmatically via `DevSettings`; both calls are `suspend`/`Flow` based:

```kotlin
val context = LocalContext.current
val scope = rememberCoroutineScope()

scope.launch {
    DevSettings.activateDevTool(context, activate = true)   // or false
}

val isActivated: Flow<Boolean> = DevSettings.isDevToolActivated(context)
```

Inside the sheet, `DevAction.ActivateDevTool` submitted to the `DevViewModel` toggles the same flag.

# 📦 Releasing

Bump `VERSION_NAME` in `gradle.properties`, merge to `main`, then push `main` to `production`.
The `Publish` workflow builds, tests, signs and uploads all three artifacts to Maven Central and creates a GitHub release tagged with the version.

# 📄 License

```
Copyright 2024 Apps with love AG

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
