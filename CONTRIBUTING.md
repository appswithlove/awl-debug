# Contributing

The repository holds both platforms: the Gradle project in [`android/`](android) and the Swift package in [`ios/`](ios), described by the [`Package.swift`](Package.swift) at the root. Features land on both platforms with the same names, defaults and behavior; the [README](README.md) documents them side by side.

## Android

```
cd android
./gradlew build
```

`build` includes `apiCheck`. After an intended public API change, run `./gradlew apiDump` and commit the updated `api/*.api` files. Change `debug` and `debug-no-op` together; `apiParityCheck` fails when their public APIs differ.

| Module and artifact | Contents |
|---|---|
| `debug-api` | Contract types and the extension API, pulled in by both others |
| `debug` | The real panel |
| `debug-no-op` | The same public API with empty bodies |

The libraries compile against OkHttp 4.12, the lowest supported version. To test another one, pass `-PokhttpVersion`, for example `./gradlew :debug:testDebugUnitTest -PokhttpVersion=5.3.2`.

The example app in `android/example/` plants `DevLogTree`, fires an HTTP request, registers a demo extension section and has a switch that activates the tool.

To try an unreleased version in another project, publish to the local Maven repository and put `mavenLocal()` first in that project's repositories:

```
./gradlew publishToMavenLocal -PRELEASE_SIGNING_ENABLED=false
```

## iOS

```
xcodebuild test -scheme AWLDebugTool -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The example app in `ios/example/` shows every module and registers a demo extension section. Debug defines `AWL_DEBUG`, Release is the store configuration: archive it and run the checks in [Store builds](README.md#store-builds). Its product is called `DebugExample` so the checks don't match the app's own name.

To try an unreleased version in another app, add the package with a branch instead of a version.

## Releasing

Android and iOS share one version number.

1. Bump `VERSION_NAME` in `android/gradle.properties`, add the version to the [changelog](CHANGELOG.md) and merge to `main` via pull request.
2. Open a pull request from `main` to `production`. It requires one approval.
3. Merging runs the `Publish` workflow: build and test, sign, upload the three Android artifacts to Maven Central and create a GitHub release tagged with the version. Swift Package Manager resolves the iOS package from the same tag.

The publish job waits for the Central Portal to validate the deployment and fails with its reasons if it is rejected. Artifacts appear on Maven Central roughly 15 to 30 minutes after a successful run.
