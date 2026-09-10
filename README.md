# awl-debug

[![Maven Central](https://img.shields.io/maven-central/v/com.appswithlove.debug/debug?label=Maven%20Central)](https://central.sonatype.com/namespace/com.appswithlove.debug)
[![CI](https://github.com/appswithlove/awl-debug/actions/workflows/build.yml/badge.svg)](https://github.com/appswithlove/awl-debug/actions/workflows/build.yml)
[![API 25+](https://img.shields.io/badge/API-25%2B-brightgreen)](https://developer.android.com/tools/releases/platforms#7.1)
[![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-Material%203-4285F4)](https://developer.android.com/compose)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

An in-app debug panel for Android. Wrap your root composable once, open the sheet with a three-finger tap, and inspect logs, HTTP traffic, auth tokens, push tokens, permissions and performance without leaving the app. Release builds ship a no-op variant, so none of it ends up in production.

Made by [Apps with love](https://appswithlove.com).

## Contents

- [Features](#features)
- [Installation](#installation)
  - [1. Add the dependencies](#1-add-the-dependencies)
  - [2. Repositories](#2-repositories)
  - [3. Additional build types](#3-additional-build-types)
- [How the artifacts fit together](#how-the-artifacts-fit-together)
- [Usage](#usage)
  - [DevSheet](#devsheet)
  - [Modules](#modules)
  - [Deeplinks](#deeplinks)
  - [Session](#session)
  - [FCM push token](#fcm-push-token)
  - [Custom modules](#custom-modules)
  - [HTTP logging](#http-logging)
  - [Timber integration](#timber-integration)
  - [Activate and deactivate](#activate-and-deactivate)
- [Local development](#local-development)
- [Releasing](#releasing)
- [License](#license)

## Features

- Debug sheet opens and closes with a three-finger tap
- Logs: Timber and HTTP entries, filter by query, export to file
- HTTP inspector via an OkHttp interceptor
- Deeplinks: fire ad-hoc or preconfigured deeplinks from the sheet
- Session: inspect, copy, edit or delete auth tokens per provider
- FCM push token: display, refresh, revoke (you supply the source, no Firebase dependency)
- Permissions, performance and accessibility modules
- Test crashes
- App info from your build config plus custom key/value pairs
- Custom modules: append your own composables to the sheet
- No-op artifact for release builds

## Installation

### 1. Add the dependencies

```kotlin
dependencies {
    debugImplementation("com.appswithlove.debug:debug:0.6.0")
    releaseImplementation("com.appswithlove.debug:debug-no-op:0.6.0")
}
```

Two lines, one per build type: the `debug` build gets the real panel, the `release` build gets a stub with the same API and empty bodies. Your app code stays identical for both. Details in [How the artifacts fit together](#how-the-artifacts-fit-together).

### 2. Repositories

All artifacts are on [Maven Central](https://central.sonatype.com/namespace/com.appswithlove.debug). New Android projects already have it configured:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

No token, no extra repository.

### 3. Additional build types

`debugImplementation` and `releaseImplementation` only cover the two default build types. If your app declares more (`staging`, `qa`, ...), each one needs its own line, otherwise that build type has neither artifact and fails to compile:

```kotlin
stagingImplementation("com.appswithlove.debug:debug:0.6.0")       // internal build: real panel
qaImplementation("com.appswithlove.debug:debug-no-op:0.6.0")      // goes to external testers: stub
```

Rule of thumb: `debug` for builds that stay inside the team, `debug-no-op` for anything that leaves the building.

## How the artifacts fit together

awl-debug ships as a real + no-op pair with a shared API, the same pattern [LeakCanary](https://square.github.io/leakcanary/) and [Chucker](https://github.com/ChuckerTeam/chucker) use. Your app calls `DevSheet { ... }`, `Timber.plant(DevLogTree())` and `DevHttpLogInterceptor()` unconditionally. Which implementation ends up in the APK is decided by Gradle per build type, not by `if (BuildConfig.DEBUG)` checks in your code.

| Artifact | Contents | Weight |
|---|---|---|
| `debug-api` | Contract types only: `DevConfig`, `DevModulesConfig`, `DeeplinkItem`, `SessionProvider`, `FcmTokenProvider`. Pulled in transitively by both AARs, never referenced directly. | a few KB |
| `debug` | The real panel: Compose sheet, three-finger gesture, log collector, HTTP interceptor, all modules, charts. | ~430 KB plus its Compose, Material 3 and Vico dependencies |
| `debug-no-op` | The same public functions and classes with empty bodies. `DevSheet` renders your `content` and nothing else; `DevLogTree` and `DevHttpLogInterceptor` discard everything. Depends only on `debug-api`. | ~14 KB |

Both AARs expose identical signatures under identical package names, so the same call sites compile against either. The shared types live in `debug-api` exactly once, so the two AARs can never collide on the classpath.

What this buys you:

- Release builds contain no debug UI, gesture detection or log buffering. Not disabled: absent from the binary.
- The Session module can read and overwrite auth tokens. That code does not exist in production builds.
- None of the panel's UI dependencies (Vico charts, extra Material 3, DataStore) are added to your release APK.
- No conditionals in app code. Plant the tree, add the interceptor, wrap your root composable, done.

The contract types live under `com.appswithlove.debug.api.*`, for example `com.appswithlove.debug.api.DevConfig` and `com.appswithlove.debug.api.session.SessionProvider`.

## Usage

### DevSheet

Wrap `DevSheet` around your top-level composable. The sheet opens with a three-finger tap while the dev tool is activated (see [Activate and deactivate](#activate-and-deactivate)).

```kotlin
DevSheet(
    devConfig = DevConfig(
        versionName = BuildConfig.VERSION_NAME,
        versionCode = BuildConfig.VERSION_CODE,
        flavor = BuildConfig.FLAVOR,
        buildType = BuildConfig.BUILD_TYPE,
    ),
) {
    MyApp()
}
```

| Parameter | Default | Description |
|---|---|---|
| `devConfig` | `null` | Build info shown in the App Info module: version name and code, flavor, build type, plus optional `customParams: Map<String, String>` |
| `modulesConfig` | `DevModulesConfig()` | Which built-in modules are shown and their inputs, see [Modules](#modules) |
| `customModules` | empty | Composable lambda appended at the bottom of the sheet, see [Custom modules](#custom-modules) |
| `isAlwaysActive` | `false` | When `true`, the three-finger tap works even if the dev tool is deactivated |
| `swipeToDismiss` | `false` | When `true`, the sheet can be dismissed by swiping down |
| `inheritHostTheme` | `false` | When `true`, the sheet uses the host app's `MaterialTheme` instead of its own |
| `logHistory` | `LogCollector.logHistory` | Log source to display; override to use a custom collector instance |
| `modifier` | `Modifier` | Applied to the wrapping container |

### Modules

`DevModulesConfig` controls which modules appear. Everything is enabled by default; modules that need input (deeplinks, session, FCM) hide themselves when nothing is provided.

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        showPerformanceModule = false,
        showAccessibilityModule = false,
    )
) {
    MyApp()
}
```

| Field | Default | Module |
|---|---|---|
| `showLogsModule` | `true` | Logs (Timber + HTTP) |
| `showPerformanceModule` | `true` | Performance |
| `showPermissionsModule` | `true` | Permissions |
| `showAccessibilityModule` | `true` | Accessibility |
| `showDeeplinksModule` / `deeplinks` | `true` / empty | [Deeplinks](#deeplinks) |
| `showSessionModule` / `sessionProviders` | `true` / empty | [Session](#session), hidden when the list is empty |
| `showFcmPushTokenModule` / `fcmTokenProvider` | `true` / `null` | [FCM push token](#fcm-push-token), hidden when `null` |
| `showTestCrashesModule` | `true` | Test crashes |

### Deeplinks

Fire deeplinks straight from the sheet to test navigation. Enter a URL and tap **Shoot**, or preconfigure a list for one-tap access:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        deeplinks = listOf(
            DeeplinkItem(label = "Home", url = "myapp://home"),
            DeeplinkItem(label = "Profile", url = "myapp://profile/123"),
        )
    )
) {
    MyApp()
}
```

### Session

Inspect and manipulate the current auth state per token source:

- Shows logged in / logged out status per provider
- Copies the current token to the clipboard
- Edits the token (for example paste an invalid one to trigger a refresh), only when `onSetToken` is provided
- Deletes the token to break the session, only when `onSetToken` is provided

Implement `SessionProvider` for each token source and pass the list:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        sessionProviders = listOf(
            object : SessionProvider {
                override val label = "Auth Token"
                override val token: Flow<String?> = authStorage.tokenFlow

                // optional: omit to hide the Edit and Delete buttons
                override val onSetToken: suspend (String?) -> Unit = { authStorage.setToken(it) }
            },
            object : SessionProvider {
                override val label = "Refresh Token"
                override val token: Flow<String?> = authStorage.refreshTokenFlow
                override val onSetToken: suspend (String?) -> Unit = { authStorage.setRefreshToken(it) }
            },
        )
    )
) {
    MyApp()
}
```

`token` must emit whenever the value changes (login, logout, refresh); that is how the module stays in sync without manual refreshes. The module is hidden when `sessionProviders` is empty.

### FCM push token

Displays the current push token and, optionally, lets you refresh or revoke it. The library has no Firebase dependency; you supply the token and the actions:

```kotlin
DevSheet(
    modulesConfig = DevModulesConfig(
        fcmTokenProvider = object : FcmTokenProvider {
            override val token: Flow<String?> = fcmStorage.tokenFlow

            // optional: omit to hide the button
            override val onRefresh: suspend () -> Unit = {
                FirebaseMessaging.getInstance().deleteToken().await()
                fcmStorage.set(FirebaseMessaging.getInstance().token.await())
            }

            // optional: omit to hide the button
            override val onRevoke: suspend () -> Unit = {
                FirebaseMessaging.getInstance().deleteToken().await()
                fcmStorage.set(null)
            }
        }
    )
) {
    MyApp()
}
```

`token` must emit whenever it changes so the displayed value stays current. Each button only appears when its action is provided. The module is hidden when `fcmTokenProvider` is `null`.

### Custom modules

Append your own composables to the bottom of the sheet:

```kotlin
DevSheet(
    customModules = {
        Text("Feature flags: ${flags.joinToString()}")
    }
) {
    MyApp()
}
```

### HTTP logging

Add `DevHttpLogInterceptor` to your `OkHttpClient`. Every request and response shows up in the Logs module:

```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor(DevHttpLogInterceptor())
    .build()
```

### Timber integration

Plant `DevLogTree` in `Application.onCreate()` to forward Timber logs to the panel:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree(), DevLogTree())
    }
}
```

`DevLogTree` only logs to the panel. Keep `Timber.DebugTree()` alongside it if you also want logcat output.

### Activate and deactivate

The three-finger tap only opens the sheet while the dev tool is activated, unless `isAlwaysActive = true`. The flag is persisted on the device. Toggle it from your own UI, for example a hidden switch in settings:

```kotlin
val context = LocalContext.current
val scope = rememberCoroutineScope()
val isActivated by DevSettings.isDevToolActivated(context).collectAsState(initial = false)

Switch(
    checked = isActivated,
    onCheckedChange = { scope.launch { DevSettings.activateDevTool(context, it) } },
)
```

`DevSettings.activateDevTool(context, Boolean)` is a `suspend` function; `DevSettings.isDevToolActivated(context)` returns a `Flow<Boolean>`. Inside the sheet, the App Info module offers the same toggle.

## Local development

Build and test:

```
./gradlew build
```

Run the sample app from `sample/` to try the panel. It plants `DevLogTree`, fires an HTTP request and exposes a switch that activates the dev tool.

To test an unreleased version in another project, publish to your local Maven repository. The flag skips GPG signing, which is only needed for Maven Central:

```
./gradlew publishToMavenLocal -PRELEASE_SIGNING_ENABLED=false
```

Then, in the consuming project, put `mavenLocal()` first in its repositories and depend on the version from `gradle.properties`:

```kotlin
repositories {
    mavenLocal()
    google()
    mavenCentral()
}

dependencies {
    debugImplementation("com.appswithlove.debug:debug:<VERSION_NAME>")
    releaseImplementation("com.appswithlove.debug:debug-no-op:<VERSION_NAME>")
}
```

## Releasing

1. Bump `VERSION_NAME` in `gradle.properties` and merge to `main` via pull request.
2. Open a pull request from `main` to `production`. It requires one approval.
3. Merging runs the `Publish` workflow: build and test, sign, upload all three artifacts to Maven Central, create a GitHub release tagged with the version.

The publish job waits for the Central Portal to validate the deployment and fails with the portal's reasons if it is rejected. Artifacts appear on Maven Central roughly 15 to 30 minutes after a successful run.

## License

```
Copyright 2024 Apps with love AG

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
