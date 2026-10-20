# awl-debug

[![Maven Central](https://img.shields.io/maven-central/v/com.appswithlove.debug/debug?label=Maven%20Central)](https://central.sonatype.com/namespace/com.appswithlove.debug)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-F05138)](#ios)
[![Android 7.1+ · iOS 16+](https://img.shields.io/badge/Android%207.1%2B%20%C2%B7%20iOS%2016%2B-blue)](#installation)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

An in-app debug panel for Android and iOS test builds. Testers open it with a three-finger tap and inspect logs, network traffic, performance, permissions and session tokens, record the screen or fire deeplinks, without leaving the app. Both platforms have the same modules and are configured the same way. Store builds never contain the tool.

Made by [Apps with love](https://appswithlove.com).

## Contents

- [Features](#features)
- [Installation](#installation)
- [Setup](#setup)
- [Configuration](#configuration)
- [Opening the panel](#opening-the-panel)
- [Modules](#modules)
- [Network](#network)
- [Logs](#logs)
- [Session](#session)
- [Deeplinks](#deeplinks)
- [FCM push token](#fcm-push-token)
- [Screen recording](#screen-recording)
- [Custom sections](#custom-sections)
- [Extensions](#extensions)
- [Store builds](#store-builds)
- [Migrating to 2.0](MIGRATION.md)
- [Contributing](CONTRIBUTING.md)

## Features

- Opens with a three-finger tap, triple tap, shake or screenshot, or from code
- App Info with build and device details and a version overlay on the screen
- Logs: Timber and Kermit on Android, the unified log (`os_log`, `Logger`, Kermit) on iOS; search, severity filter, export
- Network: every OkHttp or `URLSession` request with redacted headers and bodies, filters, search, detail, cURL copy and export
- Performance: CPU, RAM, battery and UI freezes, with a draggable overlay
- Permissions, Accessibility (font size, Light/Dark/System), Deeplinks, Session tokens, FCM push token
- Screen recording of the app's own windows, secure fields masked, kept after a crash, exported as MP4, contact sheet and timeline
- Clear App Data and Test Crashes
- Extensions: other libraries add rows to the panel and read logs, requests and the screen recording

## Installation

### Android

Requires API 25 (Android 7.1). All artifacts are on [Maven Central](https://central.sonatype.com/namespace/com.appswithlove.debug), no extra repository or token.

```kotlin
dependencies {
    debugImplementation("com.appswithlove.debug:debug:2.0.0")
    releaseImplementation("com.appswithlove.debug:debug-no-op:2.0.0")
}
```

`debug-no-op` has the same API with empty bodies, so app code stays identical for both build types. Every additional build type needs its own line, otherwise it has neither artifact and fails to compile. Rule of thumb: `debug` for builds that stay inside the team, `debug-no-op` for anything that leaves the building:

```kotlin
stagingImplementation("com.appswithlove.debug:debug:2.0.0")
qaImplementation("com.appswithlove.debug:debug-no-op:2.0.0")
```

### iOS

Requires iOS 16.

1. In Xcode, choose **File > Add Package Dependencies…**, enter `https://github.com/appswithlove/awl-debug` and add the product `AWLDebugTool` to the app target, from version `2.0.0` up to the next major version. In a `Package.swift`: `.package(url: "https://github.com/appswithlove/awl-debug", from: "2.0.0")`.
2. In **General > Frameworks, Libraries, and Embedded Content**, set `AWLDebugTool` to **Embed & Sign**. It is a dynamic framework so store builds can remove it; without embedding, the app crashes at launch with `Library not loaded: @rpath/AWLDebugTool.framework/AWLDebugTool`.
3. Define the flag in the configurations of test builds only: **Build Settings > Other Swift Flags** (`OTHER_SWIFT_FLAGS`) `$(inherited) -DAWL_DEBUG`, and compile every use of the tool behind `#if AWL_DEBUG`. The [store build](#store-builds) script reads exactly this setting, so don't use **Active Compilation Conditions**.

## Setup

### Android

Wrap the root composable, plant the log tree and add the interceptor. No `if (BuildConfig.DEBUG)` needed; Gradle picks the implementation per build type.

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree(), DevLogTree())
    }
}

val client = OkHttpClient.Builder()
    .addInterceptor(DevHttpLogInterceptor())
    .build()

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

### iOS

Start the tool as early as possible and add the panel to the root view:

```swift
import SwiftUI
#if AWL_DEBUG
import AWLDebugTool
#endif

@main
struct MyApp: App {
    init() {
#if AWL_DEBUG
        var config = AWLDebugConfig()
        config.triggers = [.threeFingerTap, .shake]
        AWLDebugTool.start(config: config)
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if AWL_DEBUG
                .includeDebugTool()
#endif
        }
    }
}
```

UIKit apps without a SwiftUI root call `AWLDebugTool.install(in: windowScene)` instead of `includeDebugTool()`, after the scene's window is visible, for example at the end of `scene(_:willConnectTo:options:)`. Requests of `URLSession.shared` and of sessions created after `start` are captured without further code.

## Configuration

| Setting | Android | iOS | Default |
|---|---|---|---|
| Triggers | `DevSheet(triggers =)` | `config.triggers` | three-finger tap |
| Open while deactivated | `DevSheet(isAlwaysActive =)` | `config.isAlwaysActive` | `false` |
| Build info | `DevSheet(devConfig =)`, with `customParams` | read from the bundle | |
| Network capture and redaction | `DevHttpLogInterceptor(DevNetworkConfig(…))` | `config.network` | see [Network](#network) |
| Log sources | `DevLogTree`, `DevKermitLogWriter` | `config.logs` | see [Logs](#logs) |
| Token sources | `DevModulesConfig(sessionProviders =)` | `config.sessionProviders` | empty |
| Deeplinks | `DevModulesConfig(deeplinks =, deeplinkHandler =)` | `AWLDebugTool.start(deeplinks:)` | empty |
| FCM push token | `DevModulesConfig(fcmTokenProvider =)` | `includeDebugTool(fcmToken:)` | none |
| Screen recording | `DevModulesConfig(screenRecording =)` | `config.screenRecording` | off, 5 min |
| Version overlay | `DevModulesConfig(showVersionOverlay =)` | `config.showVersionOverlay` | `true` |
| Hide a module | `DevModulesConfig(show…Module = false)` for every module | `showSessionModule`, `showFCMPushTokenModule` | all shown |
| Custom sections | `DevSheet(customModules =)` | `includeDebugTool(customView:)` | none |
| App groups for Clear App Data | | `config.appGroupIdentifiers` | empty |
| Panel style | `DevSheet(swipeToDismiss =, inheritHostTheme =)` | | `false` |

## Opening the panel

| Trigger | Android `DevTrigger` | iOS `AWLDebugTrigger` | Notes |
|---|---|---|---|
| Three-finger tap | `ThreeFingerTap` | `.threeFingerTap` | Emulator: two fingers. Simulator: hold Option and tap with two fingers. |
| Triple tap | `TripleTap` | `.tripleTap` | One finger within 600 ms; the app still receives the taps |
| Screenshot | `Screenshot` | `.screenshot` | Android 14 and later; the `debug` artifact declares `DETECT_SCREEN_CAPTURE` for it |
| Shake | `Shake` | `.shake` | Simulator: **Device > Shake** |

A trigger only opens the panel. Triggers work while the tool is activated; the value is stored on the device, and `isAlwaysActive = true` skips the check. Android starts deactivated, iOS activated. Toggle it from your own UI, for example a hidden switch in settings; App Info in the panel offers the same switch.

```kotlin
DevSettings.activateDevTool(context, true)          // suspend
DevSettings.isDevToolActivated(context)             // Flow<Boolean>
```

```swift
AWLDebugTool.isActivated = false
AWLDebugTool.open()   // also close(), toggle(), isOpen; open() ignores isActivated
```

## Modules

The start page shows App Info, the [extension](#extensions) sections and the modules in the same order on both platforms. A green dot marks a module that records or measures.

| Module | What it does |
|---|---|
| App Info | Version, build, device model, OS version and more. Tap the header to collapse it to one line. "Show version overlay" shows `AWL <version> (<build>)` at the top start, visible in screenshots but not in the panel. |
| Logs | See [Logs](#logs) |
| Network | See [Network](#network) |
| Performance | CPU, RAM, battery and UI freezes (over 700 ms), on iOS also main-thread latency, with a draggable overlay. Measures only while its switch or the overlay is on. |
| Permissions | Status of the declared permissions and "Open app settings". The tool never requests one. |
| Accessibility | Font size and appearance (System, Light, Dark) for the app, without changing the device settings. On Android 12+ the appearance goes through `UiModeManager.setApplicationNightMode`, so "System" also replaces a night mode the app set itself. |
| Deeplinks | See [Deeplinks](#deeplinks) |
| Session | See [Session](#session) |
| FCM push token | See [FCM push token](#fcm-push-token) |
| Screen Recording | See [Screen recording](#screen-recording) |
| Clear App Data | After a confirmation, resets the app. Android: `clearApplicationUserData()`, which also ends the process. iOS: `UserDefaults` and optionally keychain, files and cookies; the tool's own settings stay. |
| Test Crashes | Crashes the app after a confirmation, to check the crash reporting |

## Network

Every request is recorded with method, URL, status, duration, headers and bodies; on Android it also gets a one-line summary in Logs. The list marks requests above `slowRequestThresholdMs` as "slow". Filters by method, status and host and the sort order are saved on the device. The detail shows headers and bodies and copies the request as cURL; "Export" shares `awl-debug-network-<timestamp>.txt` with the current filters applied.

Values are redacted on the device before anything is stored:

- `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie` and userinfo in URLs, always
- Header names in `redactHeaders`, case-insensitive
- JSON, form and multipart fields in `redactJsonFields` and query parameters in `redactQueryParams`, at any depth; matching ignores case, `_` and `-`

Bodies are cut off after `maxBodyBytes`, after redaction. Streams (`text/event-stream`, `application/x-ndjson`, `streamContentTypes`) are never read, and on Android binary content and one-shot bodies are replaced with a placeholder. `captureBodies = false` stores no bodies.

| Option | Default |
|---|---|
| `captureBodies` | `true` |
| `maxBodyBytes` | `256 * 1024` |
| `redactHeaders` | empty |
| `redactJsonFields` | `password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `credential`, `apiKey`, `clientSecret` |
| `redactQueryParams` | same as `redactJsonFields` |
| `slowRequestThresholdMs` | `1_000` |
| `streamContentTypes` | empty |

```kotlin
DevHttpLogInterceptor(
    DevNetworkConfig(
        redactHeaders = setOf("X-Api-Key"),
        redactJsonFields = DevNetworkConfig().redactJsonFields + "pin",
    )
)
```

```swift
config.network = .init(redactHeaders: ["X-Api-Key"],
                       redactJsonFields: AWLDebugConfig.NetworkConfig.defaultRedactedFields.union(["pin"]))
```

- **Android:** use `addNetworkInterceptor()` instead to also see headers OkHttp adds, such as cookies. The library compiles against OkHttp 4.12 and works with OkHttp 5.
- **iOS:** a `URLProtocol` captures `URLSession.shared` and sessions created from `.default` or `.ephemeral` after `start`, including Ktor's Darwin engine. The tool never trusts a certificate by itself, so TLS behaves as without it.

## Logs

Log messages from every source are redacted before they are stored: `Bearer` and `Basic` credentials and the default `redactJsonFields`, also in stringified or truncated JSON. Search and severity filter also apply to the export.

- **Android:** `DevLogTree` forwards Timber with tag and throwable; keep `Timber.DebugTree()` for logcat. Kotlin Multiplatform apps add `Logger.addLogWriter(DevKermitLogWriter())` from Android code that already depends on `debug` / `debug-no-op`, for example the `Application`. Kermit is `compileOnly`, so the app's version is used.
- **iOS:** the module reads the app's unified log (`os_log`, `Logger`, Kermit's `OSLogWriter`) without code in the app, without Apple's own subsystems. Add entries with `AWLDebugTool.log("message", level: .warn, tag: "Auth", error: error)`. `config.logs = .init(subsystems: ["com.example.app"])` limits the subsystems, `readOSLog: false` turns reading off.

## Session

One provider per token source. The panel shows each token masked (first 6 and last 4 characters) with "Reveal" and "Copy". Actions appear only when the app offers them: "Edit" and "Delete" with a token setter, "Invalidate" (calls the app's invalidate, or writes `<token>.invalid` so the next request gets a 401), "Login", "Refresh" and "Logout". Failures show "Action failed: …". Without providers the module shows how to add one.

```kotlin
DevModulesConfig(
    sessionProviders = listOf(
        object : SessionProvider {
            override val label = "Access Token"
            override val token: Flow<String?> = authStorage.tokenFlow   // emit on every change
            override val onSetToken: suspend (String?) -> Unit = { authStorage.setToken(it) }
        },
        // stores without a Flow: read every second while the panel shows it
        PollingSessionProvider(label = "Refresh Token", onSetToken = { store.write(it) }) { store.read() },
    ),
)
```

```swift
config.sessionProviders = [
    AWLTokenProvider(label: "Access Token",
                     token: { await authEngine.accessToken },
                     setToken: { await authEngine.setAccessToken($0) },
                     refresh: { try await authEngine.refresh() },
                     logout: { await authEngine.logout() }),
]
// live updates: conform to AWLSessionProvider and stream through token: AsyncStream<String?>
```

## Deeplinks

Fire predefined deeplinks or the testers' own, which are saved on the device. Scheduling posts a notification after a few seconds that opens the deeplink, to test a cold start. Scheduling needs the notification permission; the tool never requests it and explains why scheduling isn't possible without it.

```kotlin
DevModulesConfig(
    deeplinks = listOf(DeeplinkItem(label = "Home", url = "myapp://home")),
    deeplinkHandler = { url -> navigator.open(url) },   // default: ACTION_VIEW within the app's package
)

// With a handler, forward launch intents in onCreate and onNewIntent of the launcher activity
AwlDebug.handleDeeplinkIntent(intent)
```

```swift
AWLDebugTool.start(deeplinks: .init(deeplinks: [AWLDeeplink(title: "Home", url: "myapp://home")],
                                    handler: .uiApplicationSharedOpen),   // or .custom { url in … }
                   config: config)

// In UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)
if AWLDebugTool.processDeeplinkNotificationIfNeeded(response) { completionHandler(); return }
```

## FCM push token

Shows the current push token with "Copy". The tool has no Firebase dependency; the app passes the token. Without a token the row shows how to pass one.

```kotlin
DevModulesConfig(
    fcmTokenProvider = object : FcmTokenProvider {
        override val token: Flow<String?> = fcmStorage.tokenFlow
        override val onRefresh: suspend () -> Unit = { /* optional */ }
        override val onRevoke: suspend () -> Unit = { /* optional */ }
    },
)
```

```swift
ContentView().includeDebugTool(fcmToken: pushService.fcmToken)
```

## Screen recording

Records the app's own windows at 3 frames per second, only while testers touch, type or the keyboard or orientation changes. No system screen capture, so no permission prompt. Recording is off until a tester turns it on; while it runs, the version overlay shows a red dot. Nothing is recorded while the panel is open or the app is in the background.

```kotlin
DevModulesConfig(screenRecording = DevScreenRecordingConfig(isOnByDefault = false, maxDurationSeconds = 300))
```

```swift
config.screenRecording = .init(isOnByDefault: false, maxDuration: .seconds(300))
```

- Frames are a ring buffer of 30 s, 1, 5 or 10 min of activity. On the next start they move to "last recording", so the steps before a crash survive.
- The export contains `recording.mp4`, `frames.jpg` (contact sheet) and `timeline.md` (one row per frame, touch, keyboard or orientation change).
- Password and secure text fields are always black. Mark other sensitive views; on Android the markers do nothing in `debug-no-op`, on iOS keep them behind `#if AWL_DEBUG`:

```kotlin
Text(text = iban, modifier = Modifier.awlDebugMasked())   // Compose
cardView.awlDebugMasked = true                             // View, covers its children
```

```swift
Text(iban).awlDebugMasked()          // SwiftUI
view.awlDebugMasked = true           // UIKit
```

On Android, dialog windows and windows with `FLAG_SECURE` are not recorded. Recordings can contain personal data, so mask what isn't a password field.

## Custom sections

Add your own UI at the end of the start page:

```kotlin
DevSheet(customModules = { Text("Feature flags: ${flags.joinToString()}") }) { MyApp() }
```

```swift
ContentView().includeDebugTool(customView: {
    Section("Feature flags") { Toggle("New checkout", isOn: $flags.newCheckout) }
})
```

## Extensions

Other libraries add rows to the panel and read what it captured through `AwlDebugExtensions` (Android, in `debug-api`) or `AWLDebugExtensions` (iOS). Everything they read is already redacted. Sections appear below App Info, sorted by `order`, then by registration; the same `id` replaces a section. Rows are drawn in the panel's style, and callbacks run on the main thread. `claimedTriggers` are gestures the extension handles itself; they no longer open the panel.

```kotlin
val registration = AwlDebugExtensions.register(
    DevExtensionSection(
        id = "my-extension",
        order = 10,
        claimedTriggers = setOf(DevTrigger.Shake),
        items = MutableStateFlow(listOf(
            DevExtensionItem.Title("My extension", DevExtensionAction("Sync now") { sync() }),
            DevExtensionItem.Text("ID: 3f2a9c1e", DevTextStyle.Monospace, copyValue = "3f2a9c1e"),
            DevExtensionItem.Switch("Enabled", checked = true) { setEnabled(it) },
            DevExtensionItem.Link("Open my screen", badge = "2 new") { openMyScreen() },
        )),
    ),
)
registration.close()   // removes the section
```

```swift
let section = AWLDebugExtensionSection(id: "my-extension", order: 10)
section.items = [
    .title("My extension", action: AWLDebugExtensionAction("Sync now") { sync() }),
    .text("ID: 3f2a9c1e", style: .monospace, copyValue: "3f2a9c1e"),
    .toggle("Enabled", isOn: true) { setEnabled($0) },
    .link("Open my screen", badge: "2 new") { openMyScreen() },
]
section.claimedTriggers = [.shake]
let registration = AWLDebugExtensions.register(section)
registration.cancel()   // removes the section
```

| Android | iOS | Returns |
|---|---|---|
| `logSnapshot(maxEntries)` | `logSnapshot(maxEntries:)` | Newest log entries with the Logs module's filter applied, oldest first, plus the filter |
| `networkSnapshot(maxEntries)` | `networkSnapshot(maxEntries:)` | Newest captured requests, without filters |
| `addNetworkListener { }` | `observeNetwork(_:)` | Every finished request from now on, on a background thread |
| `hasRecording()` | `hasRecording` | Whether recording is on and frames of this or the previous run exist |
| `exportRecording(options)` | `exportRecording(_:)` | `recording.mp4`, `frames.jpg`, `timeline.md` within `lastSeconds`, `maxVideoBytes`, `maxTimelineBytes`; a too large video is encoded once more at half size |
| `isDebugArtifactPresent` | `isStarted` | Whether the real tool runs |
| | `closePanel()`, `excludeFromCapture(_:)`, `keepOnClearAppData(userDefaultsPrefix:)` | Close the panel, skip the extension's own requests, keep its settings |

On Android a library only depends on `debug-api`; with `debug-no-op` the calls compile and do nothing. On iOS ship an extension as a dynamic framework too, so store builds remove it with `AWLDebugTool`. An extension window over the app sets `accessibilityIdentifier = "AWLDebugWindow"` so recordings leave it out. Both sample apps register a demo section.

## Store builds

The tool must never reach the Play Store, App Store or external testers.

**Android:** use `debug-no-op` for those build types. Release builds then contain no debug UI, gestures, log buffering or token access, and none of the panel's dependencies. The build enforces that `debug` and `debug-no-op` have the same public API. To check a release APK, the count must be `0`:

```
apkanalyzer manifest print app-release.apk | grep -ci awldebug
```

**iOS:** store configurations leave `AWL_DEBUG` unset and remove the framework:

1. In the store configuration, set `OTHER_LDFLAGS = $(inherited) -Wl,-dead_strip_dylibs`.
2. Add a Run Script build phase after **Embed Frameworks** and set `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the target. Packages built on the tool add their frameworks to the `rm` line:
   ```bash
   # Keeps the AWL debug SDK out of configurations without AWL_DEBUG (store builds).
   [[ " ${OTHER_SWIFT_FLAGS:-} " == *" -DAWL_DEBUG "* ]] && exit 0
   cd "${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}" || exit 1
   # The framework, plus the package's resource bundle that Xcode copies to the app's root.
   rm -rf Frameworks/AWLDebugTool.framework AWLDebugTool_AWLDebugTool.bundle
   if otool -L "${EXECUTABLE_NAME:?}" | grep -q AWLDebug; then
       echo "error: the store build still links the AWL debug SDK"; exit 1
   fi
   ```

Check the archived store app; all three counts must be `0`. The checks search for "AWLDebug", so they only work for an app whose name doesn't contain it:

```bash
APP=path/to/MyApp.app
nm -a "$APP/MyApp" | grep -ci AWLDebug
otool -L "$APP/MyApp" | grep -c AWLDebug
find "$APP" -iname "*AWLDebug*" | wc -l
```

## License

[Apache 2.0](LICENSE), © Apps with love AG
