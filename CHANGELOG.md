# Changelog

## 2.0.2

- iOS: WebSockets stay connected. The Network module loaded every request through its `URLProtocol`, including `URLSessionWebSocketTask`, which dropped the connection with `NSURLErrorDomain -1005`. WebSockets, Server-Sent Events (`Accept: text/event-stream`), download tasks and upload tasks above 1 MB or with a streamed body now go to the system untouched; the list shows them from their metadata once they finish, without bodies. See [WebSockets and streams on iOS](README.md#websockets-and-streams-on-ios). Apps that marked such requests with `AWLDebugExtensions.excludeFromCapture` as a workaround can remove it.
- iOS: redaction runs on a background queue instead of the URL loading thread that all custom protocols share, and finished requests reach the list in batches, at most ten main thread updates per second.
- Android: `DevHttpLogInterceptor` no longer reads a response body ahead of the app. A streamed text body without a declared stream type, such as chunked JSON, reached the app only after it ended or 1 MB arrived. The body is now copied while the app reads it, and the request is stored once the body was read to the end or closed. Redaction runs on a background thread, outside the request.
- Android: a request body of unknown length is read at most up to 1 MB for the capture, instead of to its end.

## 2.0.1

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
