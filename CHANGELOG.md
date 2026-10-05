# Changelog

From 2.0.0 on, Android and iOS share this repository and one version number. Older versions: Android awl-debug up to 0.6.1, iOS AWLDebugTool up to 1.0.17.

## 2.0.0 (unreleased)

Upgrade guides: [Android from 0.6](android/README.md#migrating-from-06) and [iOS from AWLDebugTool 1.x](ios/README.md#migrating-from-awldebugtool-1x).

### Both platforms

- The panel has the same modules in the same order on Android and iOS: App Info, Logs, Network, Performance, Permissions, Accessibility, Deeplinks, Session, FCM push token, Screen Recording, Clear App Data and Test Crashes.
- Configurable triggers: three-finger tap (default), triple tap, shake and screenshot. A trigger only opens the panel.
- Network module: list, filters, search, detail with headers and bodies, cURL copy and export. Credentials, cookies and sensitive JSON, form and query fields are redacted on the device, and bodies are capped.
- Logs: credentials and sensitive JSON fields are redacted in messages, and the export follows the search and severity filters.
- Performance: CPU, RAM, battery and UI freezes, with a draggable overlay. Sampling only runs while measuring is on or the overlay is visible.
- Version overlay with the app's version and build, which testers can switch off.
- App Info collapses to one summary line from its header; the choice is saved on the device.
- Session: edit, delete, invalidate, log in, refresh and log out per token source. Without token sources the module shows how to add one; `showSessionModule` hides it.
- Deeplinks: testers save their own deeplinks and schedule delayed deeplinks through a notification to test cold starts.
- Accessibility: font size and Light, Dark or System appearance for the app.
- Clear App Data.
- Screen recording: the app's own windows at 3 frames per second while testers use the app, secure fields masked, kept after a crash, exported as MP4 video, contact sheet and timeline.
- Extension API (`AwlDebugExtensions` on Android, `AWLDebugExtensions` on iOS): other libraries add rows to the panel and read logs, requests and the screen recording.

### Android

- **Breaking:** `DevHttpLogInterceptor` takes a `DevNetworkConfig` instead of a `DevLogCollector`.
- **Breaking:** `DevSheet` has a `triggers` parameter after `modulesConfig`, and a trigger no longer closes an open sheet.
- **Breaking:** `isAlwaysActive` no longer changes the activation stored on the device.
- New: `DevNetworkConfig`, `DevTrigger`, `DevScreenRecordingConfig`, `PollingSessionProvider`, `SessionProvider.onInvalidate`, `DevKermitLogWriter`, `AwlDebug.handleDeeplinkIntent`, `Modifier.awlDebugMasked()` and `View.awlDebugMasked`.
- The library's `FileProvider` has its own authority, `${applicationId}.awldebug.fileprovider`, and no longer clashes with the app's provider.
- The library no longer sets `android:allowBackup="false"` on the app.
- `DevLogTree` keeps the Timber tag and throwable.
- The build fails when the public APIs of `debug` and `debug-no-op` differ.

### iOS

- **Breaking:** the package moved to `https://github.com/appswithlove/awl-debug`. Product and module are still `AWLDebugTool`.
- **Breaking:** the product is a dynamic framework. Apps embed it, and store builds remove it with a build phase.
- **Breaking:** the default trigger is the three-finger tap instead of the triple tap.
- **Breaking:** network capture no longer trusts every server certificate.
- New: `AWLDebugConfig` with network, logs, triggers, session providers, screen recording, version overlay and app group options; `AWLDebugTool.log`, `open()`, `close()`, `toggle()`, `isOpen` and `isActivated`; `AWLDebugTool.install(in:)` for UIKit apps; `AWLSessionProvider` and `AWLTokenProvider`; `.awlDebugMasked()`.
- The panel opens in its own window above the app's sheets, and each module has its own page.
- The Logs module reads the app's unified log, so `os_log`, `Logger` and Kermit entries appear without extra code.
- The Permissions module shows the status of the declared permissions and never requests one.
- Screen recording no longer swizzles methods and masks secure text fields.
- The Network page shows "Filters", "Export", "Clear", "Dynamic data" and "Number of logs per session" above the list, and how many requests the filters hide.
- The FCM push token row is always on the start page; without a token it shows how to pass one. New: `AWLDebugConfig.showFCMPushTokenModule`.
- Deprecated: `start(isScreenRecordingOn:)`, `start(tokens:)` with `TokenDebugModel`, and `includeDebugTool(showDebugToolEvents:)`.
