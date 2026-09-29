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
            isScreenRecordingOn: false, // 1. Enable screen recording
            deeplinks: .init(               // optional, lets you fire/pre-configure deeplinks from the debug panel
                deeplinks: [AWLDeeplink(title: "Home", url: "myapp://home")],
                handler: .uiApplicationSharedOpen // or .custom { url in ... } if you don't use URL schemes
            ),
            config: {
                var config = AWLDebugConfig()
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

`AWLDebugConfig.triggers` picks the gestures, any of `.threeFingerTap` (default), `.tripleTap` (three quick taps with one finger), `.screenshot` and `.shake`. A trigger that `AWLDebugFeedback` also handles opens feedback only and logs a warning. `showDebugToolEvents` is deprecated: `.threeTaps` is `.tripleTap`, `.userDidTakeScreenshot` is `.screenshot`.

Gestures work only while `AWLDebugTool.isActivated` is `true` (default, stored per device, kept by "Clear App Data"); apps can hide the panel behind their own switch by setting it to `false`. `AWLDebugConfig.isAlwaysActive = true` skips that check, `AWLDebugTool.open()` always works.

From code, for example from a custom module: `AWLDebugTool.open()`, `AWLDebugTool.close()`, `AWLDebugTool.toggle()`, `AWLDebugTool.isOpen`.

UIKit apps without a SwiftUI root call `AWLDebugTool.install(in: windowScene)` instead of `includeDebugTool()`, after the scene's window is visible (for example at the end of `scene(_:willConnectTo:options:)`).

## Usage
<b>Functionalities</b>

### 1. About
- user can see general data about underlying app
(device, app name, app version and build number, current time, internet access)
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

### 5. Simulate crash
- user can simulate crash to check if firebase integration works.

### 6. Session / Tokens
- developer passes one provider per token source in `AWLDebugConfig.sessionProviders`: `AWLTokenProvider(label:token:…)` reads the token on demand (a KMP `suspend` getter works too), or the app conforms its own type to `AWLSessionProvider` and streams changes through `token: AsyncStream<String?>`
- the panel shows each token masked (first 6, last 4 characters) with "Reveal token" and "Copy" (the pasteboard forgets it after 60 s), and follows login, refresh and logout live
- actions appear only when the app offers them: "Edit" and "Delete" with `setToken` (empty value deletes), "Invalidate" writes `<token>.invalid` via `setToken` or calls `invalidate`, "Login", "Refresh", "Logout"; all are `async throws`, failures show "Action failed: …"
- the module is hidden without providers; `AWLDebugTool.start(tokens:)` with `TokenDebugModel` still works but is deprecated

### 7. Display FCM push token
- user can see currently used FCM pushed token. It's useful during testing to send pushes directly to the device.

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
- you can switch ON/OFF recording via debug panel. (default state you can set by AWLDebugTool.start(isScreenRecordingOn: true))
- it is possible to share last video: if app crashes, the video contains steps to reproduce crash.
- it is possible to share current video: if you found a bug you can attach the video. Last frame of the video contains the app version.
- you can limit duration of videos. By default it is 5 minutes.

NOTES:
- IMPORTANT: be careful, videos can contain your password!
- process of recording can be a reason of short FREEZES or PERFORMANCE issues!
- the video consists of a set of user actions and is not tied to real time.
- Usually videos have small size, so it is easy to attach to a task.

### 13. Settings
- user can adjust settings for DebugTool

### 14. Feedback (`AWLDebugFeedback`)
Separate product. Testers report a finding from a system screenshot or a device shake: they mark up the screen, describe the issue by typing or on-device dictation, and send it to the feedback service.

```swift
import AWLDebugFeedback

#if DEBUG || STAGING
RootView()
    .feedbackTool(config: FeedbackConfig(
        endpoint: URL(string: "https://feedback.example.com")!,
        appKey: "<app key>",
        appVersion: "1.0",
        buildNumber: "42",
        environment: "staging",
        extraMetadata: { ["screen": currentScreenName] }
    ))
#endif
```

- Attach once, at the root. `feedbackTool(config: nil)` does nothing.
- `distribution` is optional and only sent when set, because older feedback services reject unknown metadata keys.
- Reporter: the first report asks for the tester's name (required) and email (optional), kept on the device (`UserDefaults`); later reports show "Sent as {name}" with "Change". `FeedbackConfig(reporter:)` fills it in until the tester enters their own. Sent as `reporter` in the metadata, so the feedback service must accept that key.
- Markup: "Pen", "Arrow" (colours Red, Yellow, Green, Blue, Black) and "Redact", a black rectangle burnt into the screenshot before it leaves the device; the original is never sent.
- Offline queue: when the service cannot be reached (network error, timeout, 5xx, 429), the report is saved in `Library/Application Support/AWLDebug/feedback-queue/` ("Saved. It will be sent when you are online.") and sent again on app start, when the app becomes active and when the network changes. Retries back off from 30 s to 1 h and respect `Retry-After`. At most 20 reports or 50 MB are kept, the oldest are dropped first. Other errors (400, 401, 403, 413, 415, 422) are shown and not queued. Every attempt of a report carries the same `Idempotency-Key` header, so the service stores it once.
- "Attach logs" (default on, `FeedbackConfig(attachLogsByDefault:)`) adds `logs.txt` when `AWLDebugTool` is also in the app and started: app and device info, the last 500 entries of the Logs module with its active filters, and the last 50 requests (headers only, no bodies), all already redacted. At most 1 MB; the oldest entries are left out first. Without `AWLDebugTool` the switch is hidden. The two products do not link each other: feedback finds the tool at runtime.
- Dictation needs `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in the app's `Info.plist`.
- Tests: `xcodebuild test -scheme AWLDebugTool-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

## Store builds
The SDK must never ship to the App Store. Compile every call behind a flag that store configurations do not define (e.g. `AWL_DEBUG`). Package products cannot be linked per configuration, so both products are dynamic frameworks. Store configurations then remove them:

1. In the store configuration's xcconfig, drop the load commands of unused frameworks:
   ```
   OTHER_LDFLAGS = $(inherited) -Wl,-dead_strip_dylibs
   ```
2. Add a Run Script build phase to the app target, after "Embed Frameworks":
   ```bash
   # Keeps the AWL debug SDK out of configurations without AWL_DEBUG.
   [[ " ${OTHER_SWIFT_FLAGS:-} " == *" -DAWL_DEBUG "* ]] && exit 0
   rm -rf "${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks/AWLDebugTool.framework" \
          "${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks/AWLDebugFeedback.framework"
   if otool -L "${TARGET_BUILD_DIR}/${WRAPPER_NAME}/${EXECUTABLE_NAME}" | grep -q AWLDebug; then
       echo "error: the store build still links the AWL debug SDK"; exit 1
   fi
   ```

Verify on the built store app; all three counts must be `0`:
```bash
APP=path/to/MyApp.app
nm -a "$APP/MyApp" | grep -ciE "AWLDebug|AWLFeedback"
otool -L "$APP/MyApp" | grep -c AWLDebug
find "$APP" -iname "*AWLDebug*" | wc -l
```
