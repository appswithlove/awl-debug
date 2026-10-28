# Changelog

## Unreleased

- Android: `debug` declares `POST_NOTIFICATIONS` for scheduled deeplinks, so app lint no longer fails with `NotificationPermission`. The tool still never requests it. `debug-no-op` is unchanged.

## 2.0.0

One debug panel for Android and iOS. Both platforms live in this repository, share one version number and have the same modules, configured the same way. Coming from Android awl-debug 0.6 or iOS AWLDebugTool 1.x: see the [migration guide](MIGRATION.md).

- Modules on both platforms: App Info, Logs, Network, Performance, Permissions, Accessibility, Deeplinks, Session, FCM push token, Screen Recording, Clear App Data and Test Crashes.
- Network: filters, search, request details, cURL copy and export. Credentials and sensitive fields are redacted on the device.
- Screen recording of the app's own windows with secure fields masked, exported as MP4, contact sheet and timeline.
- Triggers: three-finger tap, triple tap, shake or screenshot.
- Saved and delayed deeplinks, session invalidation and a version overlay.
- Extension API (`AwlDebugExtensions` on Android, `AWLDebugExtensions` on iOS): other libraries add rows to the panel and read logs, requests and the screen recording.
- iOS: a dynamic framework that store builds remove; the Logs module reads the app's unified log, including `Logger` and Kermit.
