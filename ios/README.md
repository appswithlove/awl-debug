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
            tokens: [                      // optional, exposes session tokens for viewing/invalidation
                AWLDebugTool.TokenDebugModel(label: "Access Token", getToken: { authEngine.accessToken })
            ]
        )
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG || STAGING
              .includeDebugTool(
                  fcmToken: userNotificationService.fcmToken, // 2. Add view
                  // fcmToken is optional, if you do not support pushes or don't want to expose the token, you can omit it.
                  showDebugToolEvents: [.threeTaps, .userDidTakeScreenshot] // when to open the debug panel, defaults to [.threeTaps]
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

3. Open AWLDebugTool inside app by clicking 3 times on screen (or by taking a screenshot, if `.userDidTakeScreenshot` is included in `showDebugToolEvents`)

## Usage
<b>Functionalities</b>

### 1. About
- user can see general data about underlying app
(device, app name, app version and build number, current time, internet access)
- app version and build number are also always visible in a small overlay in the top-left corner of the screen

### 2. Network logging
- user can record network logs.
- user can see network logs in real time and filter them.
- user can export network logs.

### 3. UserDefaults
- user can clear UserDefaults for underlying app.

### 4. Permissions
- user can change permissions for underlying app (Location, Camera, ...)

### 5. Simulate crash
- user can simulate crash to check if firebase integration works.

### 6. Session / Tokens
- developer can expose session tokens (e.g. access/refresh token) via `AWLDebugTool.start(tokens:)`, by passing an `AWLDebugTool.TokenDebugModel` per token with a label and a closure returning its current value
- user can view and copy each token's current value from the debug panel
- user can trigger token invalidation to test the app's refresh/re-authentication flow

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
