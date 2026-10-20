# Migrating to 2.0

2.0 brings Android and iOS into this repository with one version number and the same panel on both platforms.

- [Android from 0.6](#android-from-06)
- [iOS from AWLDebugTool 1.x](#ios-from-awldebugtool-1x)

## Android from 0.6

Version 2.0 keeps the artifacts, packages and the `DevSheet` call. Check these changes:

- **Interceptor:** `DevHttpLogInterceptor` takes a `DevNetworkConfig` instead of a `DevLogCollector`. `DevHttpLogInterceptor()` stays valid. Requests now appear in the Network module, with a one-line summary in Logs.
- **Triggers:** `DevSheet` has a new `triggers` parameter after `modulesConfig`. If you pass `customModules` or later parameters by position, name them. A trigger only opens the sheet; it no longer closes an open one.
- **`isAlwaysActive`:** it no longer changes the activation stored on the device. Use `DevSettings.activateDevTool` for that.
- **`FileProvider`:** the authority is `${applicationId}.awldebug.fileprovider` instead of `${applicationId}.fileprovider`, so it no longer clashes with your app's provider. Remove workarounds such as `tools:node="remove"` for the library's provider.
- **Manifest:** the library no longer sets `android:allowBackup="false"` on your app; drop a `tools:replace="android:allowBackup"` you added for it. The `debug` artifact declares `DETECT_SCREEN_CAPTURE` for the screenshot trigger.
- **Logs:** `Log` has the new optional fields `tag` and `throwable`; `DevLogTree` now keeps the Timber tag and throwable.

New modules are shown by default: Network (once a `DevHttpLogInterceptor` exists), Clear App Data and Screen Recording, where recording stays off until a tester turns it on. The version overlay is on by default too; turn it off with `DevModulesConfig(showVersionOverlay = false)`. Also new: saved and delayed deeplinks, session invalidation, `DevKermitLogWriter`, `AwlDebug.handleDeeplinkIntent` and the [extension API](android/README.md#extensions).

## iOS from AWLDebugTool 1.x

The calls of 1.x still compile; the old variants are deprecated. These changes need action:

- **Package URL:** replace the package with `https://github.com/appswithlove/awl-debug`, see [Installation](ios/README.md#installation). Product and module are still called `AWLDebugTool`.
- **Dynamic framework:** set `AWLDebugTool` to **Embed & Sign**. 1.x was linked statically; without embedding, the app crashes at launch on devices and in release builds.
- **Store builds:** replace `#if DEBUG || STAGING` with `#if AWL_DEBUG` and add the steps in [Store builds](ios/README.md#store-builds). Without them, the framework ships in store builds.
- **Default trigger:** the panel opens with a three-finger tap instead of a triple tap. To keep the 1.x behavior, set `config.triggers = [.tripleTap]`, or `[.tripleTap, .screenshot]` if you used `.userDidTakeScreenshot`.
- **TLS:** the tool no longer accepts every server certificate. A server with an invalid certificate now fails in debug builds too, as it does in store builds.

| 1.x | 2.0 |
|---|---|
| `AWLDebugTool.start(isScreenRecordingOn: true, …)` | `config.screenRecording.isOnByDefault = true` |
| `AWLDebugTool.start(tokens: [.init(label:getToken:)])` | `config.sessionProviders = [AWLTokenProvider(label:token:…)]` |
| `.includeDebugTool(showDebugToolEvents: [.threeTaps, .userDidTakeScreenshot])` | `config.triggers = [.tripleTap, .screenshot]` |
| UserDefaults module | Clear App Data, with keychain, files and cookies as options |
