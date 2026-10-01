# AWLDebugTool

An in-app debug panel for iOS test builds. Add the package, start the tool once, and open the panel with a three-finger tap to inspect logs, network traffic, session tokens, permissions and performance, record the screen, or fire deeplinks. Store builds never contain it.

Made by [Apps with love](https://appswithlove.com). The Android version in [`android/`](../android/README.md) has the same modules.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Setup](#setup)
- [Opening the panel](#opening-the-panel)
- [Modules](#modules)
- [Network](#network)
- [Logs](#logs)
- [Session](#session)
- [Deeplinks](#deeplinks)
- [Screen recording](#screen-recording)
- [Custom sections](#custom-sections)
- [Extensions](#extensions)
- [Store builds](#store-builds)
- [Migrating from AWLDebugTool 1.x](#migrating-from-awldebugtool-1x)
- [Tests](#tests)

## Features

- Panel in its own window, above the app's sheets and full-screen covers. It opens with a three-finger tap, triple tap, shake or screenshot (configurable) or from code.
- App Info: version, build, device model, iOS version, locale, time and internet status, plus a version overlay on the screen
- Logs: the app's unified-log entries (`os_log`, `Logger`, Kermit) without extra code, plus `AWLDebugTool.log(…)`; search, level filter, export
- Network: every `URLSession` request with redacted headers and bodies, filters, search, detail, cURL copy and export
- Performance: CPU, RAM, main-thread latency, battery and UI freezes, with a draggable overlay
- Permissions, Accessibility (Dynamic Type preview, Light/Dark/System appearance), Deeplinks, Session tokens, FCM push token
- Screen recording: the app's windows at 3 fps while testers interact, secure fields masked, kept after a crash, exported as MP4, contact sheet and timeline
- Clear App Data and Test Crashes
- Extensions: other packages add rows to the panel and read logs, requests and the last screen recording

Requires iOS 16 or later.

## Installation

### 1. Add the package

In Xcode, choose **File > Add Package Dependencies…**, enter `https://github.com/appswithlove/awl-debug` and add the product `AWLDebugTool` to the app target. As requirement, use the version `2.0.0` up to the next major version; until 2.0.0 is released, use the branch `release/2.0`.

In a `Package.swift`:

```swift
.package(url: "https://github.com/appswithlove/awl-debug", from: "2.0.0")
// before the release: .package(url: "https://github.com/appswithlove/awl-debug", branch: "release/2.0")
```

### 2. Embed the framework

`AWLDebugTool` is a dynamic framework, so store builds can remove it (see [Store builds](#store-builds)). In the app target's **General > Frameworks, Libraries, and Embedded Content**, set it to **Embed & Sign**. Without that, only Debug builds in the Simulator start; everywhere else the app crashes at launch with `Library not loaded: @rpath/AWLDebugTool.framework/AWLDebugTool`.

### 3. Set the `AWL_DEBUG` flag

Compile every use of the tool behind `#if AWL_DEBUG`, and define the flag only in the configurations of test builds: **Build Settings > Other Swift Flags** (`OTHER_SWIFT_FLAGS`) `$(inherited) -DAWL_DEBUG`. The script in [Store builds](#store-builds) reads exactly this setting, so don't use **Active Compilation Conditions** for it.

The Example app in [`Example/`](Example) uses this setup: Debug defines `AWL_DEBUG`, Release is the store configuration.

## Setup

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
        config.sessionProviders = [
            AWLTokenProvider(label: "Access Token",
                             token: { await authEngine.accessToken },
                             setToken: { await authEngine.setAccessToken($0) },
                             refresh: { try await authEngine.refresh() },
                             logout: { await authEngine.logout() })
        ]
        AWLDebugTool.start(
            deeplinks: .init(deeplinks: [AWLDeeplink(title: "Home", url: "myapp://home")],
                             handler: .uiApplicationSharedOpen), // or .custom { url in … }
            config: config
        )
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if AWL_DEBUG
                .includeDebugTool(fcmToken: pushService.fcmToken) // fcmToken is optional
#endif
        }
    }
}
```

UIKit apps without a SwiftUI root call `AWLDebugTool.install(in: windowScene)` instead of `includeDebugTool()`, after the scene's window is visible, for example at the end of `scene(_:willConnectTo:options:)`.

Delayed deeplinks arrive as local notifications. Forward them from your `UNUserNotificationCenterDelegate`:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
#if AWL_DEBUG
    if AWLDebugTool.processDeeplinkNotificationIfNeeded(response) { completionHandler(); return }
#endif
    // handle your own notifications
    completionHandler()
}
```

| `AWLDebugConfig` | Default | Description |
|---|---|---|
| `triggers` | `[.threeFingerTap]` | Gestures that open the panel, see [Opening the panel](#opening-the-panel) |
| `isAlwaysActive` | `false` | Gestures open the panel even when `AWLDebugTool.isActivated` is `false` |
| `network` | `NetworkConfig()` | Capture and redaction, see [Network](#network) |
| `logs` | `LogsConfig()` | Unified-log reading, see [Logs](#logs) |
| `sessionProviders` | empty | Token sources of the Session module; the module is hidden without providers |
| `screenRecording` | off, 5 min | See [Screen recording](#screen-recording) |
| `showVersionOverlay` | `true` | Default of the version overlay; testers can switch it off in App Info |
| `appGroupIdentifiers` | empty | App-group `UserDefaults` suites that Clear App Data also empties |

## Opening the panel

| `AWLDebugTrigger` | Gesture |
|---|---|
| `.threeFingerTap` | Three fingers at once. In the Simulator, hold Option and tap with two fingers. |
| `.tripleTap` | Three quick taps with one finger; the app still receives the taps |
| `.screenshot` | A system screenshot |
| `.shake` | Shaking the device (Simulator: **Device > Shake**) |

A trigger only opens the panel. Gestures work while `AWLDebugTool.isActivated` is `true`, the default; the value is stored per device and kept by Clear App Data. To hide the panel behind a switch of your own, set it to `false`. `AWLDebugConfig.isAlwaysActive = true` skips the check.

From code, for example from a custom section: `AWLDebugTool.open()`, `AWLDebugTool.close()`, `AWLDebugTool.toggle()` and `AWLDebugTool.isOpen`. `open()` works regardless of `isActivated`.

## Modules

The start page shows App Info, the sections of [extensions](#extensions) and the modules in a fixed order, the same as on Android. Each module opens its own page with Back and Close. A green dot marks a module that records or measures.

| Module | What it does |
|---|---|
| App Info | App name, version, build, device model (for example `iPhone17,1`, never the device name), iOS version, locale, time and internet status. Long-press a value to copy it. "Show version overlay" shows `AWL <version> (<build>)` at the top left, above sheets too. |
| Logs | See [Logs](#logs) |
| Network | See [Network](#network) |
| Performance | CPU (the process's share of all cores, 0–100 %), RAM, main-thread latency and battery level, with a draggable overlay. A main-thread ping that waits longer than 700 ms counts as a UI freeze. Measuring runs only while "Measure performance" is on or the overlay is visible. |
| Permissions | Status of the permissions the app declares a usage description for, and "Open app settings". The tool never requests a permission. |
| Accessibility | Font size (Dynamic Type, Extra Small to Accessibility XXXL) and appearance (System, Light, Dark) for the app's windows, without changing the device settings |
| Deeplinks | See [Deeplinks](#deeplinks) |
| Session | See [Session](#session) |
| FCM Push Token | The token passed to `includeDebugTool(fcmToken:)`; long-press to copy. Hidden without a token. |
| Screen Recording | See [Screen recording](#screen-recording) |
| Clear App Data | After a confirmation, deletes the app's `UserDefaults` and, if selected, keychain items, files, and cookies with caches. The tool's own settings stay. |
| Test Crashes | "Simulate crash - Runtime exception" and "Simulate crash - Index out of bounds" crash the app after a confirmation, to check that the app's crash reporting catches it. The message is "AWL Debug test crash". |

## Network

The tool registers a `URLProtocol` and captures requests of `URLSession.shared` and of sessions created from `URLSessionConfiguration.default` or `.ephemeral` after `AWLDebugTool.start`. Ktor's Darwin engine uses such a session, so Kotlin Multiplatform apps need no extra code.

The module lists requests with time, method, status, duration and host, and marks requests above `slowRequestThresholdMs` as "slow". Filters by method, status and host and the sort order are stored on the device. The detail shows headers and bodies and copies the request as cURL. "Export network logs" shares `awl-debug-network-<timestamp>.txt`.

Values are redacted on the device before anything is stored:

- `Authorization`, `Proxy-Authorization`, `Cookie` and `Set-Cookie`, always.
- Header names in `redactHeaders` (case-insensitive).
- JSON fields at any depth, form fields and query parameters in `redactJsonFields` and `redactQueryParams`. Matching ignores case, `_` and `-`.

Bodies are cut off after `maxBodyBytes`, after redaction. Streams (`text/event-stream`, `application/x-ndjson` and `streamContentTypes`) are never read. `captureBodies = false` stores no bodies.

```swift
var config = AWLDebugConfig()
config.network = .init(redactHeaders: ["X-Api-Key"],
                       redactJsonFields: AWLDebugConfig.NetworkConfig.defaultRedactedFields.union(["pin"]),
                       slowRequestThresholdMs: 2_000)
```

| `NetworkConfig` | Default |
|---|---|
| `captureBodies` | `true` |
| `maxBodyBytes` | `256 * 1024` |
| `redactHeaders` | empty |
| `redactJsonFields` | `password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `credential`, `apiKey`, `clientSecret` |
| `redactQueryParams` | same as `redactJsonFields` |
| `streamContentTypes` | empty |
| `slowRequestThresholdMs` | `1_000` |

Authentication challenges go to the app's own session; the tool never trusts a certificate by itself, so TLS behaves as without the tool.

## Logs

The Logs module shows the app's own unified-log entries (`os_log`, `Logger`, Kermit's `OSLogWriter`) without any code in the app, plus entries added with `AWLDebugTool.log("message", level: .warn, tag: "Auth", error: error)`. Apple's own subsystems (`com.apple.*`) are left out. `AWLDebugConfig(logs: .init(subsystems: ["com.example.app"]))` shows only the listed subsystems, and `readOSLog: false` turns reading off.

`Bearer` and `Basic` credentials are redacted before an entry is stored, and JSON fields from the default `redactJsonFields` list get the value `"[REDACTED]"`, also in stringified or truncated JSON. Search and level filters also apply to "Export logs".

## Session

Pass one provider per token source in `AWLDebugConfig.sessionProviders`. `AWLTokenProvider(label:token:…)` reads the token on demand, and a Kotlin Multiplatform `suspend` getter works too. For live updates, conform your own type to `AWLSessionProvider` and stream changes through `token: AsyncStream<String?>`.

- The panel shows each token masked (first 6 and last 4 characters) with "Reveal token" and "Copy"; the pasteboard forgets it after 60 seconds.
- Actions appear only when the app offers them: "Edit" and "Delete" with `setToken` (an empty value deletes), "Invalidate" (writes `<token>.invalid` through `setToken`, or calls `invalidate`), "Login", "Refresh" and "Logout". All are `async throws`; failures show "Action failed: …".

## Deeplinks

- Fire the deeplinks passed to `AWLDebugTool.start(deeplinks:)` right away, or schedule them as a local notification after 5 or 10 seconds to test a cold start.
- Testers can add, edit and remove their own deeplinks; they are stored on the device.
- `.uiApplicationSharedOpen` opens URLs with `UIApplication.shared.open`; use `.custom { url in … }` for your own navigation.
- Scheduling needs the notification permission. The tool never requests it and explains why scheduling isn't possible without it.
- Forward the notification to `AWLDebugTool.processDeeplinkNotificationIfNeeded(_:)`, or to `processDeeplinkNotificationInfoIfNeeded(_:)` with only the `userInfo`, see [Setup](#setup).

## Screen recording

The Screen Recording module records the app's own windows (sheets and alerts included; not the debug panel, windows of extensions or the keyboard) and the version overlay as frames, 3 per second and only while the app is used: up to one second after a touch, typing, a keyboard or orientation change, plus two frames after that. Touches show as circles, green where they begin and red where they end.

```swift
config.screenRecording = .init(isOnByDefault: false, maxDuration: .seconds(300)) // 30 s, 1, 5 or 10 min
```

- Testers switch recording on or off in the panel; the choice is stored on the device. While recording is on, the version overlay shows a red dot. Nothing is recorded while the panel is open or the app is in the background.
- Frames are kept in `Library/Caches/AWLDebug/recording/current/` and moved to `last/` on the next start, so after a crash the module shows "Last recording available ({date})" and "Export last recording" contains the steps before the crash.
- "Export current recording" and "Export last recording" share `awl-debug-recording-<yyyy-MM-dd_HH.mm.ss>.zip` with `recording.mp4` (H.264, 3 fps, long edge at most 1280 px; the time axis only has active frames), `frames.jpg` (contact sheet, 4 columns, at most 60 frames with their times) and `timeline.md` (one row per frame, touch, keyboard or orientation change, pauses as `gap`).
- Secure text fields (`UITextField.isSecureTextEntry`, SwiftUI `SecureField`) are always covered with a black rectangle, in the same frame. While such a view moves, for example in a sheet sliding in, no frame is taken. Mark other views with `.awlDebugMasked()` (SwiftUI) or `view.awlDebugMasked = true` (UIKit). Store builds don't link the framework, so wrap the marker in your app:
  ```swift
  extension View {
      @ViewBuilder func debugMasked() -> some View {
  #if AWL_DEBUG
          awlDebugMasked()
  #else
          self
  #endif
      }
  }
  ```
- Touches are observed by a gesture recognizer on each app window that never recognizes, so the app receives every touch unchanged; nothing is swizzled. Only drawing the windows runs on the main thread; masks, circles, JPEG encoding and file access run in the background.

Recordings can contain personal data. Mask sensitive views that aren't secure text fields.

## Custom sections

Add your own SwiftUI sections at the end of the start page:

```swift
ContentView()
    .includeDebugTool(customView: {
        Section("Feature flags") {
            Toggle("New checkout", isOn: $flags.newCheckout)
        }
    })
```

## Extensions

Other packages build on the tool through `AWLDebugExtensions`: they add rows to the panel and read what the tool records, without private API. Everything they read is already redacted, like in the panel.

```swift
#if AWL_DEBUG
import AWLDebugTool

@MainActor
final class MyModule {
    private let section = AWLDebugExtensionSection(id: "my-module", order: 10)
    private var registration: AWLDebugRegistration?

    func install() {
        section.items = [
            .title("My module", action: AWLDebugExtensionAction("Refresh") { /* … */ }),
            .text("Last sync 10:42"),
            .text("Device ID: 1234", style: .monospace, copyValue: "1234"),  // tap to copy
            .toggle("Upload", isOn: true) { isOn in /* store it, then update `items` */ },
            .link("Open report", badge: "2 pending") { /* runs after the panel closed */ },
        ]
        section.claimedTriggers = [.shake]  // handled by the module; no longer opens the panel
        registration = AWLDebugExtensions.register(section)
    }
}
#endif
```

| API | Description |
|---|---|
| `register(_:)` | Shows the section on the start page below App Info, sorted by `order`, then by registration. The same `id` replaces a section; `cancel()` on the returned registration removes it. Rows are drawn in the panel's style; callbacks run on the main actor. |
| `claimedTriggers` | Triggers the module handles itself. They don't open the panel; if `AWLDebugConfig.triggers` has one, the panel logs a warning. |
| `observeNetwork(_:)` | Every request the Network module captures, redacted, on a background queue in the order they finish. Works before `start`. |
| `networkSnapshot(maxEntries:)` | The newest requests of the Network module, ordered by start time. |
| `logSnapshot(maxEntries:)` | The newest entries of the Logs module with its level and search filter applied, oldest first, plus the active filter. `nil` before `start`. |
| `hasRecording`, `exportRecording(_:)` | The current screen recording, or the previous run's (`hasRecording` only while screen recording is switched on), as `recording.mp4`, `frames.jpg` and `timeline.md`. Options: `lastSeconds`, `maxVideoBytes` (too large: once more at half size, then `isVideoTooLarge`), `maxTimelineBytes`. |
| `closePanel()` | Closes the panel and returns once it is gone, for example before a screenshot. |
| `excludeFromCapture(_:)` | Marks the module's own request, so the Network module doesn't capture it. |
| `keepOnClearAppData(userDefaultsPrefix:)` | Clear App Data keeps these `UserDefaults.standard` keys. |
| `isStarted` | `AWLDebugTool.start` ran. |

An extension that shows a window of its own over the app, for example a form, sets the window's `accessibilityIdentifier` to `"AWLDebugWindow"`, like the panel: screen recordings leave it out, and typing in it is no activity.

Ship an extension as a dynamic framework too, so apps remove it from store builds together with `AWLDebugTool`. The Example's "Panel" screen adds a demo section.

## Store builds

The tool must never ship to the App Store. Store configurations leave `AWL_DEBUG` unset, so the app's code has no reference to the tool, and then remove the framework. Package products can't be linked per configuration, which is why the framework is dynamic.

1. In the store configuration, drop the load commands of unused frameworks:
   ```
   OTHER_LDFLAGS = $(inherited) -Wl,-dead_strip_dylibs
   ```
2. Add a Run Script build phase to the app target, after **Embed Frameworks**, and set `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the target, otherwise the script can't change the app bundle. Packages built on the tool add their frameworks to the `rm` line:
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

Check the archived store app; all three counts must be `0`:

```bash
APP=path/to/MyApp.app
nm -a "$APP/MyApp" | grep -ci AWLDebug
otool -L "$APP/MyApp" | grep -c AWLDebug
find "$APP" -iname "*AWLDebug*" | wc -l
```

The checks look for "AWLDebug" in names, so they only work for an app whose name doesn't contain it. That's why the Example's product is called `DebugExample`.

## Migrating from AWLDebugTool 1.x

The calls of 1.x still compile; the old variants are deprecated. These changes need action:

- **Package URL:** replace the package with `https://github.com/appswithlove/awl-debug`, see [Installation](#installation). Product and module are still called `AWLDebugTool`.
- **Dynamic framework:** set `AWLDebugTool` to **Embed & Sign**. 1.x was linked statically; without embedding, the app crashes at launch on devices and in release builds.
- **Store builds:** replace `#if DEBUG || STAGING` with `#if AWL_DEBUG` and add the steps in [Store builds](#store-builds). Without them, the framework ships in store builds.
- **Default trigger:** the panel opens with a three-finger tap instead of a triple tap. To keep the 1.x behavior, set `config.triggers = [.tripleTap]`, or `[.tripleTap, .screenshot]` if you used `.userDidTakeScreenshot`.
- **TLS:** the tool no longer accepts every server certificate. A server with an invalid certificate now fails in debug builds too, as it does in store builds.

| 1.x | 2.0 |
|---|---|
| `AWLDebugTool.start(isScreenRecordingOn: true, …)` | `config.screenRecording.isOnByDefault = true` |
| `AWLDebugTool.start(tokens: [.init(label:getToken:)])` | `config.sessionProviders = [AWLTokenProvider(label:token:…)]` |
| `.includeDebugTool(showDebugToolEvents: [.threeTaps, .userDidTakeScreenshot])` | `config.triggers = [.tripleTap, .screenshot]` |
| UserDefaults module | Clear App Data, with keychain, files and cookies as options |

## Tests

```
xcodebuild test -scheme AWLDebugTool -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The Example app in [`Example/`](Example) shows every module. Archive its Release configuration and run the checks in [Store builds](#store-builds) to verify the store setup.
