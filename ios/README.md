# AWLDebugTool

AWLDebugTool is an in-house tool developed for easier app debugging in the development process.<br>
The main functionality is to log network traffic that the app produces during usage.<br>

# Technical Requirements

- Target Platforms: iOS 15.0+

# Getting started

## Installation
1. Add AWLDebugTool as Swift package to project <br>
link: https://gitlab.appswithlove.net/ios-infra/awldebugtool <br>
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
        AWLDebugTool.start(isScreenRecordingOn: false) // 1. Enable logging
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if DEBUG || STAGING
              .includeDebugTool(fcmToken: userNotificationService.fcmToken) // 2. Add view
              // fcmToken is optional, if you do not support pushes or don't want to expose the token, you can omit it.
#endif
        }
    }
}
```

3. Open AWLDebugTool inside app by clicking 3 times on screen

## Usage
<b>Functionalities</b>

### 1. About
- user can see general data about underlying app
(device, app name, current time, internet access)

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

### 6. Display FCM push token
- user can see currently used FCM pushed token. It's useful during testing to send pushes directly to the device.

### 7. Screen recording
- you can switch ON/OFF recording via debug panel. (default state you can set by AWLDebugTool.start(isScreenRecordingOn: true))
- it is possible to share last video: if app crashes, the video contains steps to reproduce crash.
- it is possible to share current video: if you found a bug you can attach the video. Last frame of the video contains the app version.
- you can limit duration of videos. By default it is 5 minutes.

NOTES:
- IMPORTANT: be careful, videos can contain your password!
- process of recording can be a reason of short FREEZES or PERFORMANCE issues!
- the video consists of a set of user actions and is not tied to real time.
- Usually videos have small size, so it is easy to attach to a task.

### 8. Settings
- user can adjust settings for DebugTool
