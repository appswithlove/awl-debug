# awl-debug

In-app debug panel for Android and iOS test builds: logs, network traffic, performance, permissions, accessibility, deeplinks, session tokens, screen recording and more. Both platforms have the same modules and are configured the same way. Store builds never contain the tool.

Made by [Apps with love](https://appswithlove.com).

| Platform | Documentation | Install | Store builds |
|---|---|---|---|
| Android | [`android/`](android/README.md) | Maven Central, `com.appswithlove.debug:debug` for test builds and `debug-no-op` for release builds | `debug-no-op` has the same API and no implementation |
| iOS | [`ios/`](ios/README.md) | Swift Package Manager with this repository's URL, product `AWLDebugTool` | Code behind `#if AWL_DEBUG`, the dynamic framework removed by a build phase |

Other libraries can add rows to the panel and read its logs, requests and screen recording through the extension API, described in both platform READMEs.

## Versions

Android and iOS share one version number; changes are in the [changelog](CHANGELOG.md).

Coming from Android awl-debug 0.6 or iOS AWLDebugTool 1.x: see the [migration guide](MIGRATION.md).

## License

[Apache 2.0](LICENSE)
