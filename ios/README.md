# AWLDebugTool

AWLDebugTool is an in-house tool developed for easier app debugging in the development process.<br>
The main functionality is to log network traffic that the app produces during usage.<br>

# Technical Requirements

- Target Platforms: iOS 15.0+

# Getting started

## Installation
1. Add AWLDebugTool as Swift package to project <br>
link: https://github.com/appswithlove/awl-debug <br>
path: Xcode -> File -> Add Packages... -> "Search or Enter Package URL" <br>

2. Update your App.swift file <br>
IMPORTANT: avoid to publishing on PROD!

```
import SwiftUI

#if DEBUG || STAGING
import AWLDebugTool
#endif

@main
struct MyApp: App {
    
    init() {
#if DEBUG || STAGING
        AWLDebugTool.start(
            deeplinks: .init(               // optional, lets you fire/pre-configure deeplinks from the debug panel
                deeplinks: [AWLDeeplink(title: "Home", url: "myapp://home")],
                handler: .uiApplicationSharedOpen // or .custom { url in ... } if you don't use URL schemes
            ),
            config: {
                var config = AWLDebugConfig()
                config.screenRecording.isOnByDefault = false // screen recording, see 12.
                // optional, shows session tokens and lets testers edit, invalidate, log in and out
                config.sessionProviders = [
                    AWLTokenProvider(label: "Access Token",
                                     token: { await authEngine.accessToken },
                                     setToken: { await authEngine.setAccessToken($0) },
                                     refresh: { try await authEngine.refresh() },
                                     logout: { await authEngine.logout() })
                ]
                return config
            }()
        )
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG || STAGING
              .includeDebugTool(
                  fcmToken: userNotificationService.fcmToken // 2. Add view
                  // fcmToken is optional, if you do not support pushes or don't want to expose the token, you can omit it.
              )
#endif
        }
    }
}
```

If your deeplinks are delivered via local notifications scheduled from the debug panel, forward them from your `UNUserNotificationCenterDelegate`:

```
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, ...) {
    if AWLDebugTool.processDeeplinkNotificationIfNeeded(response) { return }
    // handle your own notifications
}
```

3. Open AWLDebugTool inside the app with a three-finger tap (Simulator: hold Option, tap with two fingers). The panel opens in a window of its own, above the app's sheets and full-screen covers.

`AWLDebugConfig.triggers` picks the gestures, any of `.threeFingerTap` (default), `.tripleTap` (three quick taps with one finger), `.screenshot` and `.shake`. A trigger that an extension claims (see [Extensions](#extensions)) does not open the panel; the panel logs a warning. `showDebugToolEvents` is deprecated: `.threeTaps` is `.tripleTap`, `.userDidTakeScreenshot` is `.screenshot`.

Gestures work only while `AWLDebugTool.isActivated` is `true` (default, stored per device, kept by "Clear App Data"); apps can hide the panel behind their own switch by setting it to `false`. `AWLDebugConfig.isAlwaysActive = true` skips that check, `AWLDebugTool.open()` always works.

From code, for example from a custom module: `AWLDebugTool.open()`, `AWLDebugTool.close()`, `AWLDebugTool.toggle()`, `AWLDebugTool.isOpen`.

UIKit apps without a SwiftUI root call `AWLDebugTool.install(in: windowScene)` instead of `includeDebugTool()`, after the scene's window is visible (for example at the end of `scene(_:willConnectTo:options:)`).

## Usage
The panel opens on a start page with App Info, the sections of extensions and the modules in a fixed order, the same as on Android: Logs, Network, Performance, Permissions, Accessibility, Deeplinks, Session, FCM push token, Screen Recording, Clear App Data, Test Crashes. A green dot marks a module that records or measures. Each module opens its own page with Back and Close. Sections passed as `customView` come last.

<b>Functionalities</b>

### 1. App Info
- app name, version, build, device model (e.g. `iPhone17,1`, never the device name), iOS version, locale, current time and internet status (Online/Offline); long press a value to copy it
- app version and build number are also visible in a small overlay in the top-left corner of the screen, above sheets too; testers switch it off with "Show version overlay" (stored per device), apps with `AWLDebugConfig.showVersionOverlay = false`

### 2. Network logging
- user can record network logs.
- user can see network logs in real time and filter them.
- user can export network logs.

#### App logs
The Logs module shows the app's own unified-log entries (`os_log`, `Logger`, Kermit's `OSLogWriter`) without any code in the app, plus entries added with `AWLDebugTool.log("message", level: .warn, tag: "Auth", error: error)`. Apple's own subsystems (`com.apple.*`) are left out; `AWLDebugConfig(logs: .init(subsystems: ["com.example.app"]))` shows only the listed ones. `Bearer` and `Basic` credentials are redacted before an entry is stored, and JSON fields from the default `redactJsonFields` list (`password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `credential`, `apiKey`, `clientSecret`) get the value `"[REDACTED]"`, also in stringified or truncated JSON. Search and level filters also apply to "Export logs".

### 3. UserDefaults
- user can clear UserDefaults for underlying app.

### 4. Permissions
- user can change permissions for underlying app (Location, Camera, ...)

### 5. Test Crashes
- "Simulate crash - Runtime exception" and "Simulate crash - Index out of bounds" crash the app after a confirmation, to check that the app's crash reporting (e.g. Firebase Crashlytics) catches it. The message is "AWL Debug test crash".

### 6. Session / Tokens
- developer passes one provider per token source in `AWLDebugConfig.sessionProviders`: `AWLTokenProvider(label:token:…)` reads the token on demand (a KMP `suspend` getter works too), or the app conforms its own type to `AWLSessionProvider` and streams changes through `token: AsyncStream<String?>`
- the panel shows each token masked (first 6, last 4 characters) with "Reveal token" and "Copy" (the pasteboard forgets it after 60 s), and follows login, refresh and logout live
- actions appear only when the app offers them: "Edit" and "Delete" with `setToken` (empty value deletes), "Invalidate" writes `<token>.invalid` via `setToken` or calls `invalidate`, "Login", "Refresh", "Logout"; all are `async throws`, failures show "Action failed: …"
- the module is hidden without providers; `AWLDebugTool.start(tokens:)` with `TokenDebugModel` still works but is deprecated

### 7. Display FCM push token
- user can see currently used FCM pushed token (long press to copy). It's useful during testing to send pushes directly to the device. Hidden while the app passes no token.

### 8. Deeplinks
- user can fire developer-provided deeplinks immediately, or schedule them to arrive via a local notification (5s/10s delay) to test cold-start/background handling
- user can also add, edit and remove their own ("tester") deeplinks, which persist locally on the device
- configure available deeplinks and how they're opened via `AWLDebugTool.start(deeplinks:)` (`.uiApplicationSharedOpen` or a `.custom` handler)
- for deeplinks scheduled via local notification, forward the notification to `AWLDebugTool.processDeeplinkNotificationIfNeeded(_:)` (or `processDeeplinkNotificationInfoIfNeeded(_:)` if you only have the userInfo payload) from your notification delegate

### 9. Appearance
- user can force the underlying app's color scheme to Light, Dark, or follow the system (Auto)

### 10. Accessibility
- user can preview the app with different font sizes (Dynamic Type), from Extra Small to Accessibility XXXL, without changing the device's system setting
- shortcut to open the device's Accessibility settings for reference

### 11. Performance overlay
- user can enable a draggable overlay showing live CPU usage, RAM usage and main thread latency
- helps spot performance regressions or main thread blocking directly while using the app
- measuring runs only while "Measure performance" is on or the overlay is visible; otherwise no timer runs
- CPU is the process's share of all cores (0–100 %), battery level comes from `UIDevice`, and a main-thread ping waiting longer than 700 ms counts as a UI freeze

### 12. Screen recording
- Records the app's own windows (sheets and alerts included, not the debug panel, windows of extensions or the keyboard) and the version overlay as frames, 3 per second and only while the app is used: up to one second after a touch, typing, a keyboard or orientation change, plus two frames after that. Touches show as circles (green where they begin, red where they end).
- Switch it on or off in the panel; the choice is kept on the device. Defaults come from `AWLDebugConfig.screenRecording`:
  ```swift
  config.screenRecording = .init(isOnByDefault: false, maxDuration: .seconds(300)) // 30 s, 1, 5 or 10 min
  ```
  `AWLDebugTool.start(isScreenRecordingOn:)` still works but is deprecated.
- While recording is on, the version overlay shows a red dot. Nothing is recorded while the panel is open or the app is in the background.
- Frames are kept in `Library/Caches/AWLDebug/recording/current/` and moved to `last/` on the next start, so after a crash the panel shows "Last recording available ({date})" and "Export last recording" contains the steps before the crash.
- "Export current recording" / "Export last recording" share `awl-debug-recording-<yyyy-MM-dd_HH.mm.ss>.zip` with `recording.mp4` (H.264, 3 fps, frames in recording order, so time is compressed; long edge at most 1280 px), `frames.jpg` (contact sheet, 4 columns, at most 60 frames with their times) and `timeline.md` (one row per frame, touch, keyboard or orientation change, and pauses as `gap`).
- Masking: secure text fields (`UITextField.isSecureTextEntry`, SwiftUI `SecureField`) are always covered with a black rectangle, in the same frame. While such a view moves (e.g. in a sheet sliding in), no frame is taken; a view on top only drops the mask when it really hides it (opaque, not clipped away, not moving). Mark other views with `.awlDebugMasked()` (SwiftUI) or `view.awlDebugMasked = true` (UIKit). Store builds do not link the SDK, so wrap the marker in your app:
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
- Touches are observed by a gesture recognizer on each app window that never recognises, so the app receives every touch unchanged; nothing is swizzled.
- Only drawing the windows runs on the main thread; masks, circles, JPEG encoding and file access run in the background, and a frame is skipped while the previous one is still being encoded.
- The video's time axis is compressed (only active frames), not real time.

NOTES:
- Recordings can contain personal data. Mask sensitive views that are not secure text fields.

### 13. Settings
- user can adjust settings for DebugTool

## Extensions
Other packages build on the tool through `AWLDebugExtensions`: they add rows to the panel and read what the tool records, without private API. Everything they read is already redacted, like in the panel.

```swift
#if DEBUG || STAGING
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
| `claimedTriggers` | Triggers the module handles itself. They do not open the panel; if `AWLDebugConfig.triggers` has one, the panel logs a warning. |
| `observeNetwork(_:)` | Every request the Network module captures, redacted, on a background queue in the order they finish. Works before `start`. |
| `networkSnapshot(maxEntries:)` | The newest requests of the Network module, ordered by start time. |
| `logSnapshot(maxEntries:)` | The newest entries of the Logs module with its level and search filter applied, oldest first, plus the active filter. `nil` before `start`. |
| `hasRecording`, `exportRecording(_:)` | The current screen recording, or the previous run's, as `recording.mp4`, `frames.jpg` and `timeline.md`. Options: `lastSeconds`, `maxVideoBytes` (too large: once more at half size, then `isVideoTooLarge`), `maxTimelineBytes`. |
| `closePanel()` | Closes the panel and returns once it is gone, e.g. before a screenshot. |
| `excludeFromCapture(_:)` | Marks the module's own request, so the Network module does not capture it. |
| `keepOnClearAppData(userDefaultsPrefix:)` | "Clear App Data" keeps these `UserDefaults.standard` keys. |
| `isStarted` | `AWLDebugTool.start` ran. |

An extension that shows a window of its own over the app (for example a form) sets its `accessibilityIdentifier` to `"AWLDebugWindow"`, like the panel: screen recordings leave it out, and typing in it is no activity.

The Example's "Panel" screen adds a demo section.

## Tests
`xcodebuild test -scheme AWLDebugTool -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Store builds
The SDK must never ship to the App Store. Compile every call behind a flag that store configurations do not define (e.g. `AWL_DEBUG`). Package products cannot be linked per configuration, so the product is a dynamic framework. Store configurations then remove it:

1. In the store configuration's xcconfig, drop the load commands of unused frameworks:
   ```
   OTHER_LDFLAGS = $(inherited) -Wl,-dead_strip_dylibs
   ```
2. Add a Run Script build phase to the app target, after "Embed Frameworks" (with `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the target, or the script cannot change the app bundle). Packages built on the tool add their frameworks to the list:
   ```bash
   # Keeps the AWL debug SDK out of configurations without AWL_DEBUG.
   [[ " ${OTHER_SWIFT_FLAGS:-} " == *" -DAWL_DEBUG "* ]] && exit 0
   cd "${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}" || exit 1
   # The framework, plus the package's resource bundle that Xcode copies to the app's root.
   rm -rf Frameworks/AWLDebugTool.framework AWLDebugTool_AWLDebugTool.bundle
   if otool -L "${EXECUTABLE_NAME:?}" | grep -q AWLDebug; then
       echo "error: the store build still links the AWL debug SDK"; exit 1
   fi
   ```

Verify on the archived store app; all three counts must be `0`:
```bash
APP=path/to/MyApp.app
nm -a "$APP/MyApp" | grep -ci AWLDebug
otool -L "$APP/MyApp" | grep -c AWLDebug
find "$APP" -iname "*AWLDebug*" | wc -l
```
