# awl-debug

[![Maven Central](https://img.shields.io/maven-central/v/com.appswithlove.debug/debug?label=Maven%20Central)](https://central.sonatype.com/namespace/com.appswithlove.debug)
[![CI](https://github.com/appswithlove/awl-debug/actions/workflows/build.yml/badge.svg)](https://github.com/appswithlove/awl-debug/actions/workflows/build.yml)
[![API 25+](https://img.shields.io/badge/API-25%2B-brightgreen)](https://developer.android.com/tools/releases/platforms#7.1)
[![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-Material%203-4285F4)](https://developer.android.com/compose)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

An in-app debug panel for Android. Wrap your root composable once, open the sheet with a three-finger tap, and inspect logs, HTTP traffic, auth tokens, push tokens, permissions and performance without leaving the app. Release builds ship a no-op variant, so none of it ends up in production.

Made by [Apps with love](https://appswithlove.com).

## Contents

- [Features](#features)
- [Installation](#installation)
  - [1. Add the dependencies](#1-add-the-dependencies)
  - [2. Repositories](#2-repositories)
  - [3. Additional build types](#3-additional-build-types)
- [How the artifacts fit together](#how-the-artifacts-fit-together)
  - [Store builds](#store-builds)
- [Usage](#usage)
  - [DevSheet](#devsheet)
  - [Modules](#modules)
  - [Deeplinks](#deeplinks)
  - [Session](#session)
  - [FCM push token](#fcm-push-token)
  - [Screen recording](#screen-recording)
  - [Custom modules](#custom-modules)
  - [HTTP logging](#http-logging)
  - [Timber integration](#timber-integration)
  - [Kermit integration](#kermit-integration)
  - [Activate and deactivate](#activate-and-deactivate)
  - [Extensions](#extensions)
- [Migrating from 0.6](../MIGRATION.md#android-from-06)
- [Local development](#local-development)
- [Releasing](#releasing)
- [License](#license)

## Features

- Debug sheet opens with a three-finger tap, triple tap, shake or screenshot (configurable)
- Logs: Timber and HTTP summary entries, filter by query, export to file
- Network: every OkHttp request with redacted headers and bodies, filters, search, detail, cURL copy and export
- Deeplinks: fire ad-hoc or preconfigured deeplinks from the sheet
- Session: inspect, copy, edit or delete auth tokens per provider
- FCM push token: display, refresh, revoke (you supply the source, no Firebase dependency)
- Performance: CPU, RAM, battery and UI freezes (frames over 700 ms), with charts and a draggable overlay
- Permissions and accessibility modules
- Screen recording: the app's own window at 3 fps while testers interact, password fields masked, kept after a crash
- Test crashes
- App info from your build config plus custom key/value pairs
- Custom modules: append your own composables to the sheet
- Extensions: other libraries add their own rows below App Info and read logs, requests and the last screen recording
- No-op artifact for release builds

## Installation

### 1. Add the dependencies

```kotlin
dependencies {
    debugImplementation("com.appswithlove.debug:debug:2.0.0")
    releaseImplementation("com.appswithlove.debug:debug-no-op:2.0.0")
}
```

Two lines, one per build type: the `debug` build gets the real panel, the `release` build gets a stub with the same API and empty bodies. Your app code stays identical for both. Details in [How the artifacts fit together](#how-the-artifacts-fit-together).

### 2. Repositories

All artifacts are on [Maven Central](https://central.sonatype.com/namespace/com.appswithlove.debug). New Android projects already have it configured:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

No token, no extra repository.

### 3. Additional build types

`debugImplementation` and `releaseImplementation` only cover the two default build types. If your app declares more (`staging`, `qa`, ...), each one needs its own line, otherwise that build type has neither artifact and fails to compile:

```kotlin
stagingImplementation("com.appswithlove.debug:debug:2.0.0")       // internal build: real panel
qaImplementation("com.appswithlove.debug:debug-no-op:2.0.0")      // goes to external testers: stub
```

Rule of thumb: `debug` for builds that stay inside the team, `debug-no-op` for anything that leaves the building.

## How the artifacts fit together

awl-debug ships as a real + no-op pair with a shared API, the same pattern [LeakCanary](https://square.github.io/leakcanary/) and [Chucker](https://github.com/ChuckerTeam/chucker) use. Your app calls `DevSheet { ... }`, `Timber.plant(DevLogTree())` and `DevHttpLogInterceptor()` unconditionally. Which implementation ends up in the APK is decided by Gradle per build type, not by `if (BuildConfig.DEBUG)` checks in your code.

| Artifact | Contents | Weight |
|---|---|---|
| `debug-api` | Contract types only: `DevConfig`, `DevModulesConfig`, `DevNetworkConfig`, `DeeplinkItem`, `SessionProvider`, `FcmTokenProvider`, and the [extension API](#extensions). Pulled in transitively by both AARs. | a few KB |
| `debug` | The real panel: Compose sheet, trigger gestures, log collector, HTTP interceptor, all modules, charts. | ~430 KB plus its Compose, Material 3 and Vico dependencies |
| `debug-no-op` | The same public functions and classes with empty bodies. `DevSheet` renders your `content` and nothing else; `DevLogTree`, `DevKermitLogWriter` and `DevHttpLogInterceptor` discard everything. Depends only on `debug-api`. | ~14 KB |

Both AARs expose identical signatures under identical package names, so the same call sites compile against either. The build enforces this: `apiCheck` compares each module's public API with its dump in `api/`, and `apiParityCheck` fails when `lib` and `lib-no-op` differ. The shared types live in `debug-api` exactly once, so the two AARs can never collide on the classpath.

What this buys you:

- Release builds contain no debug UI, gesture detection or log buffering. Not disabled: absent from the binary.
- The Session module can read and overwrite auth tokens. That code does not exist in production builds.
- None of the panel's UI dependencies (Vico charts, extra Material 3, DataStore) are added to your release APK.
- No conditionals in app code. Plant the tree, add the interceptor, wrap your root composable, done.

The contract types live under `com.appswithlove.debug.api.*`, for example `com.appswithlove.debug.api.DevConfig` and `com.appswithlove.debug.api.session.SessionProvider`.

### Store builds

Any build type that reaches the Play Store or external testers must use `debug-no-op`. To check a release APK, look for the `FileProvider` that only the `debug` artifact declares; the count must be `0`:

```
apkanalyzer manifest print app-release.apk | grep -ci awldebug
```

The manifest is not obfuscated, so the check also works for minified builds. `apkanalyzer` is part of the Android SDK command-line tools.

## Usage

### DevSheet

Wrap `DevSheet` around your top-level composable. The sheet opens with the configured `triggers` while the dev tool is activated (see [Activate and deactivate](#activate-and-deactivate)).

```kotlin
DevSheet(
    devConfig = DevConfig(
        versionName = BuildConfig.VERSION_NAME,
        versionCode = BuildConfig.VERSION_CODE,
        flavor = BuildConfig.FLAVOR,
        buildType = BuildConfig.BUILD_TYPE,
    ),
) {
    MyApp()
}
```

| Parameter | Default | Description |
|---|---|---|
| `devConfig` | `null` | Build info shown in the App Info module: version name and code, flavor, build type, plus optional `customParams: Map<String, String>`. Tapping the header collapses App Info to one line (app, version (code), Android version, flavor and build type); the choice is saved on the device. |
| `modulesConfig` | `DevModulesConfig()` | Which built-in modules are shown and their inputs, see [Modules](#modules) |
| `triggers` | `setOf(DevTrigger.ThreeFingerTap)` | Gestures that open the sheet, see [Triggers](#triggers) |
| `customModules` | empty | Composable lambda appended at the bottom of the sheet, see [Custom modules](#custom-modules) |
| `isAlwaysActive` | `false` | When `true`, the triggers work even if the dev tool is deactivated |
| `swipeToDismiss` | `false` | When `true`, the sheet can be dismissed by swiping down |
| `inheritHostTheme` | `false` | When `true`, the sheet uses the host app's `MaterialTheme` instead of its own |
| `modifier` | `Modifier` | Applied to the wrapping container |

#### Triggers

| `DevTrigger` | Gesture |
|---|---|
| `ThreeFingerTap` | Three fingers at once; two on an emulator |
| `TripleTap` | Three taps with one finger within 600 ms; the app still receives the taps |
| `Screenshot` | A system screenshot, Android 14 (API 34) and later. The `debug` artifact declares the `DETECT_SCREEN_CAPTURE` normal permission for it |
| `Shake` | Shaking the device (accelerometer, 2.7 g, at most once per 1.5 s) |

A trigger only opens the sheet; it never closes an open one. Shake and screenshot listeners only run while the dev tool is activated or `isAlwaysActive = true`.

```kotlin
DevSheet(triggers = setOf(DevTrigger.ThreeFingerTap, DevTrigger.Shake)) { MyApp() }
```

### Modules

`DevModulesConfig` controls which modules appear. Everything is enabled by default; modules that need input (deeplinks, session, FCM) hide themselves when nothing is provided.

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

| Field | Default | Module |
|---|---|---|
| `showLogsModule` | `true` | Logs (Timber + HTTP summaries) |
| `showNetworkModule` | `true` | [Network](#http-logging), shown once a `DevHttpLogInterceptor` exists |
| `showVersionOverlay` | `true` | Default of the "Show version overlay" switch in App Info: `AWL <versionName> (<versionCode>)` from `devConfig`, top start, touches pass through, visible in screenshots but not in the panel. Testers' choice is saved on the device. |
| `showPerformanceModule` | `true` | Performance. Samples every second, but only while its switch or the overlay ("Show performance overlay") is on. Long-press the overlay to open the module. |
| `showPermissionsModule` | `true` | Permissions |
| `showAccessibilityModule` | `true` | Accessibility: font size (system, preset steps or 50–200 %) and appearance (System, Light, Dark) for the app content, saved on the device. On Android 12+ the appearance is applied app-wide through `UiModeManager.setApplicationNightMode`; the system keeps that per app, also after restarts. Choosing "System" sets it back to `MODE_NIGHT_AUTO` (follow the device), which also replaces a night mode your app set itself. |
| `showDeeplinksModule` / `deeplinks` | `true` / empty | [Deeplinks](#deeplinks) |
| `showSessionModule` / `sessionProviders` | `true` / empty | [Session](#session); without providers the module shows how to add one |
| `showFcmPushTokenModule` / `fcmTokenProvider` | `true` / `null` | [FCM push token](#fcm-push-token), hidden when `null` |
| `showScreenRecordingModule` / `screenRecording` | `true` / off, 5 min | [Screen recording](#screen-recording) |
| `showTestCrashesModule` | `true` | Test crashes |
| `showClearAppDataModule` | `true` | Clear App Data: after a confirmation, `ActivityManager.clearApplicationUserData()` deletes all app data (including AWL Debug settings and runtime permissions) and ends the process |

### Deeplinks

Fire deeplinks straight from the sheet to test navigation. Enter a URL and tap **Fire now** or **Save** it to the testers' list on the device, or preconfigure a list (shown as "Predefined"). Tapping an entry opens its detail with **Fire now** and a cold start test: **Schedule & close app** posts a notification after 5, 10 or 30 seconds that opens the deeplink.

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

By default a deeplink starts an `ACTION_VIEW` intent limited to your app's package. To route it through your own navigation instead, set `deeplinkHandler` and pass launch intents to `AwlDebug.handleDeeplinkIntent`, so delayed deeplinks from the notification reach the handler too, also on a cold start:

```kotlin
DevSheet(modulesConfig = DevModulesConfig(deeplinkHandler = { url -> navigator.open(url) })) { MyApp() }

// In the launcher activity
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    AwlDebug.handleDeeplinkIntent(intent)
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    AwlDebug.handleDeeplinkIntent(intent)
}
```

The delayed deeplink needs the notification permission (`POST_NOTIFICATIONS` on Android 13+). The SDK neither declares nor requests it; without it the module explains why scheduling is not possible.

### Session

Inspect and manipulate the current auth state per token source:

- Shows "Logged in" / "Logged out" per provider and the token masked (first 6 and last 4 characters) until you reveal it
- Copies the current token to the clipboard (marked as sensitive)
- Edits the token (for example paste an invalid one to trigger a refresh), only when `onSetToken` is provided
- Deletes the token to break the session, only when `onSetToken` is provided
- Invalidates the token so the next request gets a 401: calls `onInvalidate`, or writes `<token>.invalid` through `onSetToken`
- Runs the app's `onLogin`, `onRefresh` and `onLogout`. While an action runs its button shows progress, errors appear as "Action failed: …"

Implement `SessionProvider` for each token source and pass the list:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        sessionProviders = listOf(
            object : SessionProvider {
                override val label = "Auth Token"
                override val token: Flow<String?> = authStorage.tokenFlow

                // optional: omit to hide the Edit and Delete buttons
                override val onSetToken: suspend (String?) -> Unit = { authStorage.setToken(it) }
            },
            object : SessionProvider {
                override val label = "Refresh Token"
                override val token: Flow<String?> = authStorage.refreshTokenFlow
                override val onSetToken: suspend (String?) -> Unit = { authStorage.setRefreshToken(it) }
            },
        )
    )
) {
    MyApp()
}
```

`token` must emit whenever the value changes (login, logout, refresh); that is how the module stays in sync without manual refreshes. Without `sessionProviders` the module page shows how to add one; `showSessionModule = false` hides the module.

Token stores without a `Flow` can use `PollingSessionProvider`, which reads a suspend getter every second while the panel shows it:

```kotlin
PollingSessionProvider(
    label = "Access Token",
    onSetToken = { tokenStore.write(it) },
    onInvalidate = { tokenStore.revokeOnServer() }, // optional, for opaque tokens
) { tokenStore.read() }
```

### FCM push token

Displays the current push token and, optionally, lets you refresh or revoke it. The library has no Firebase dependency; you supply the token and the actions:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        fcmTokenProvider = object : FcmTokenProvider {
            override val token: Flow<String?> = fcmStorage.tokenFlow

            // optional: omit to hide the button
            override val onRefresh: suspend () -> Unit = {
                FirebaseMessaging.getInstance().deleteToken().await()
                fcmStorage.set(FirebaseMessaging.getInstance().token.await())
            }

            // optional: omit to hide the button
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

`token` must emit whenever it changes so the displayed value stays current. Each button only appears when its action is provided. The module is hidden when `fcmTokenProvider` is `null`.

### Screen recording

The Screen Recording module records the activity window as JPEG frames while testers use the app. No system screen capture is involved, so there is no permission prompt. Recording is off until a tester turns it on (or `isOnByDefault = true`). While it is on, the version overlay shows a red dot.

```kotlin
DevModulesConfig(
    screenRecording = DevScreenRecordingConfig(isOnByDefault = false, maxDurationSeconds = 300),
)
```

- 3 frames per second, only while testers touch the screen, type, or open or close the keyboard, for one second after that plus two frames. An idle app records nothing, also with the keyboard open.
- Frames go to `cache/awl-debug/recording/current` as a ring buffer of the chosen length (30 s, 1 min, 5 min, 10 min of active frames). On the next start they move to `last`, so the recording survives a crash; the module then shows "Last recording available".
- Nothing is recorded while the panel is open or the app is in the background. Dialog windows (`AlertDialog`, `ModalBottomSheet`) are not part of the activity window and are missing. Windows with `FLAG_SECURE` are recorded black.
- Password fields are black: `EditText`/`TextView` with a password `inputType` and Compose fields with password semantics (`PasswordVisualTransformation`, `BasicSecureTextField`). Mark anything else:

```kotlin
Text(text = iban, modifier = Modifier.awlDebugMasked())   // Compose
cardView.awlDebugMasked = true                             // View, covers its children too
```

Both markers are in `debug` and `debug-no-op` (`com.appswithlove.debug.ui.dev.recording`), so release code compiles unchanged; in `debug-no-op` they have no effect.

### Custom modules

Append your own composables to the bottom of the sheet:

```kotlin
DevSheet(
    customModules = {
        Text("Feature flags: ${flags.joinToString()}")
    }
) {
    MyApp()
}
```

### HTTP logging

Add `DevHttpLogInterceptor` to your `OkHttpClient`. Every request is recorded in the Network module with method, URL, status, duration, headers and bodies, and a one-line summary (tag `HTTP`) shows up in the Logs module:

```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor(DevHttpLogInterceptor())
    .build()
```

Use `addNetworkInterceptor()` instead if you also want to see headers OkHttp adds, such as cookies from the `CookieJar`.

Values are redacted on the device before anything is stored:

- `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie` and userinfo in URLs (`https://[REDACTED]@host`), always.
- Header names in `redactHeaders` (case-insensitive).
- JSON fields at any depth, form fields and multipart fields in `redactJsonFields`. Matching ignores case, `_` and `-`.
- Query parameters in `redactQueryParams`, matched the same way.

Bodies are cut off after `maxBodyBytes` (default 256 KiB), after redaction. Only text bodies are stored; binary content, files in multipart bodies, one-shot and duplex request bodies, streams (`text/event-stream`, `application/x-ndjson` and `streamContentTypes`) and bodies over 1 MiB are replaced with a short placeholder. `captureBodies = false` stores no bodies at all.

```kotlin
DevHttpLogInterceptor(
    DevNetworkConfig(
        redactHeaders = setOf("X-Api-Key"),
        redactJsonFields = DevNetworkConfig().redactJsonFields + "pin",
        slowRequestThresholdMs = 2_000,
    )
)
```

| Parameter | Default |
|---|---|
| `captureBodies` | `true` |
| `maxBodyBytes` | `256 * 1024` |
| `redactHeaders` | empty |
| `redactJsonFields` | `password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `credential`, `apiKey`, `clientSecret` |
| `redactQueryParams` | same as `redactJsonFields` |
| `slowRequestThresholdMs` | `1_000` |
| `streamContentTypes` | empty (`text/event-stream` and `application/x-ndjson` are always skipped) |

The Network module lists requests with time, method, status (colored by class), duration and host + path, and marks requests above `slowRequestThresholdMs` as "slow". Search matches URL, method and status. Filters by method, status class and host, the sort order, the recording switch and "Number of logs per session" are saved on the device. The detail view shows headers and bodies (JSON indented, "Raw" toggle) and offers "Copy URL", "Copy cURL", "Copy response" and "Share". "Export network logs" shares `awl-debug-network-<timestamp>.txt` with the current search and filters applied.

Log messages from any source are also redacted: `Bearer <token>` and `Basic <credentials>` become `Bearer [REDACTED]` and `Basic [REDACTED]`, and JSON fields from the default `redactJsonFields` list (`password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `credential`, `apiKey`, `clientSecret`) get the value `"[REDACTED]"`, also in stringified or truncated JSON.

Log exports are shared through the library's own `FileProvider` (authority `${applicationId}.awldebug.fileprovider`, limited to `cacheDir/awl-debug/`), so it does not conflict with a `FileProvider` in your app.

### Timber integration

Plant `DevLogTree` in `Application.onCreate()` to forward Timber logs to the panel:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree(), DevLogTree())
    }
}
```

`DevLogTree` only logs to the panel and keeps the Timber tag and throwable of each entry. Keep `Timber.DebugTree()` alongside it if you also want logcat output.

### Kermit integration

Kotlin Multiplatform projects that log with [Kermit](https://github.com/touchlab/Kermit) add `DevKermitLogWriter` on Android. Entries keep the Kermit tag and throwable. Kermit is a `compileOnly` dependency, so your app's Kermit version is used.

Register the writer from Android code that already depends on `debug` / `debug-no-op`, for example the app's `Application`, so shared code needs no debug dependency:

```kotlin
// androidApp/src/main/kotlin/.../MyApp.kt
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Logger.addLogWriter(DevKermitLogWriter())
    }
}
```

If the writer has to be set up in the shared module, keep it in `androidMain` and give the Android target of the shared module the same `debug` / `debug-no-op` split as the app:

```kotlin
// shared/src/androidMain/kotlin/.../DebugLogging.android.kt
fun installDebugLogWriter() {
    Logger.addLogWriter(DevKermitLogWriter())
}
```

Like Timber entries, Kermit messages are redacted before they are stored (`Bearer <token>`, `Basic <credentials>`, sensitive JSON fields).

### Activate and deactivate

The triggers only open the sheet while the dev tool is activated, unless `isAlwaysActive = true`. The activation is persisted on the device (DataStore `dev_settings`); `isAlwaysActive` does not change it. Toggle it from your own UI, for example a hidden switch in settings:

```kotlin
val context = LocalContext.current
val scope = rememberCoroutineScope()
val isActivated by DevSettings.isDevToolActivated(context).collectAsState(initial = false)

Switch(
    checked = isActivated,
    onCheckedChange = { scope.launch { DevSettings.activateDevTool(context, it) } },
)
```

`DevSettings.activateDevTool(context, Boolean)` is a `suspend` function; `DevSettings.isDevToolActivated(context)` returns a `Flow<Boolean>`. Inside the sheet, the App Info module offers the same toggle.

### Extensions

Other libraries can add rows to the panel and read what it captured through `AwlDebugExtensions` in `debug-api` (package `com.appswithlove.debug.api.extension`). A library only needs `debug-api`; the app pairs `debug` and `debug-no-op` as usual.

```kotlin
val items = MutableStateFlow(
    listOf(
        DevExtensionItem.Title("My extension: On", DevExtensionAction("Sync now") { sync() }),
        DevExtensionItem.Text("3 waiting · Last sync 10:15"),
        DevExtensionItem.Text("ID: 3f2a9c1e", DevTextStyle.Monospace, copyValue = "3f2a9c1e"),
        DevExtensionItem.Switch("Enabled on this device", checked = true) { enabled -> setEnabled(enabled) },
        DevExtensionItem.Link("Open my screen", badge = "2 new") { openMyScreen() },
    ),
)
val registration = AwlDebugExtensions.register(
    DevExtensionSection(id = "my-extension", items = items, order = 10, claimedTriggers = setOf(DevTrigger.Shake)),
)
// Later, to remove the section:
registration.close()
```

- **Placement:** sections appear on the start page directly below App Info, above the built-in modules; `customModules` stay at the bottom. They are sorted by `order` (lowest first), then by registration. A section with the `id` of a registered one replaces it, and a section without items is hidden. The panel draws the rows in its own style, with a divider between sections. A link closes the panel before its action runs. Callbacks run on the main thread, and the panel follows every change of `items`.
- **`claimedTriggers`:** gestures the extension handles itself. While the section is registered, they no longer open the panel; when they are also in the `DevSheet` triggers, the panel logs a warning.
- **Data:** everything is redacted like in the panel. Lists hold the newest entries, oldest first.

| Function | Returns |
|---|---|
| `logSnapshot(maxEntries)` | Log entries that match the Logs module's search and severity filter, together with that filter. `suspend` |
| `networkSnapshot(maxEntries)` | Captured requests, without the Network module's filters |
| `addNetworkListener { record -> }` | Every request `DevHttpLogInterceptor` finishes from now on, on a background thread. Works before any interceptor exists; close the returned handle to stop |
| `hasRecording()` | Whether screen recording is switched on and frames of this or the previous run exist. Frames left after switching recording off don't count |
| `exportRecording(options)` | `recording.mp4`, `frames.jpg` and `timeline.md` within `DevRecordingExportOptions(lastSeconds, maxVideoBytes, maxTimelineBytes)`. A video above the limit is encoded once more at half the size; if it is still too large, all files are `null`. `suspend`, runs off the main thread |
| `isDebugArtifactPresent` | `true` once the `debug` artifact is in use |

- **No-op:** with `debug-no-op` the same calls compile. Sections are never shown, listeners are never called, snapshots are empty or `null`, and there is no recording.
- **Compatibility:** records such as `DevLogRecord` and `DevNetworkRecord` are plain classes, not data classes, so later versions can add fields without breaking binary compatibility.

The sample registers a demo section in `SampleApplication` (see `DemoExtension.kt`).

## Local development

Build and test:

```
./gradlew build
```

`build` includes `apiCheck`. After an intended public API change, run `./gradlew apiDump` and commit the updated `api/*.api` files. Change `lib` and `lib-no-op` together, their dumps must stay identical.

The libraries compile against OkHttp 4.12, the lowest supported version, so they do not force an upgrade on apps. Apps on OkHttp 5 get their version through Gradle resolution. To build and test against another version, pass `-PokhttpVersion`, for example `./gradlew :lib:testDebugUnitTest -PokhttpVersion=5.3.2`.

Run the sample app from `sample/` to try the panel. It plants `DevLogTree`, fires an HTTP request, registers a demo extension section and exposes a switch that activates the dev tool.

To test an unreleased version in another project, publish to your local Maven repository. The flag skips GPG signing, which is only needed for Maven Central:

```
./gradlew publishToMavenLocal -PRELEASE_SIGNING_ENABLED=false
```

Then, in the consuming project, put `mavenLocal()` first in its repositories and depend on the version from `gradle.properties`:

```kotlin
repositories {
    mavenLocal()
    google()
    mavenCentral()
}

dependencies {
    debugImplementation("com.appswithlove.debug:debug:<VERSION_NAME>")
    releaseImplementation("com.appswithlove.debug:debug-no-op:<VERSION_NAME>")
}
```

## Releasing

Android and iOS share one version number.

1. Bump `VERSION_NAME` in `android/gradle.properties` and merge to `main` via pull request.
2. Open a pull request from `main` to `production`. It requires one approval.
3. Merging runs the `Publish` workflow: build and test, sign, upload all three artifacts to Maven Central, create a GitHub release tagged with the version. Swift Package Manager resolves the iOS package from the same tag.

The publish job waits for the Central Portal to validate the deployment and fails with the portal's reasons if it is rejected. Artifacts appear on Maven Central roughly 15 to 30 minutes after a successful run.

## License

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
