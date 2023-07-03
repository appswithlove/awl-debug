# AWLDebugTool

AWLDebugTool is in-house tool developed for easier app debugging in development process.
Main functionality is to follow network traffic that the app makes during usage.

# Technical Requirements

- Target Platforms: iOS 15.0+

# Getting started

## Installation
1. add AWLDebugTool as Swift package to project
link: https://gitlab.appswithlove.net/ios-infra/awldebugtool <br>
path: Xcode -> File -> Add Packages... -> "Search or Enter Package URL"

2. add AWLDebugTool to App.swift as ViewModifier

```
import AWLDebugTool
import SwiftUI

@main
struct MyApp: App {
    @InjectedObject private var userNotificationsService: UserNotificationService

    var body: some Scene {
        WindowGroup {
            ContentView()
              .includeDebugTool(fcmToken: userNotificationsService.fcmToken ?? "")
        }
    }
}
```

3. add AWLDebugTool as singleton to code where requests are made and track them using "createNetworkLog()" method
```
import AWLDebugTool

struct BaseLoader: Loader {

    let networkLogsService = AWLDebugTool.shared

    networkLogsService.createNetworkLog(method: method.rawValue, url: urlString)

}
```

4. open AWLDebugTool inside app by clicking 10 times on screen

## Usage
<b>Functionalities</b>
1. Show network logs
- user can see information about total number of logs (e.g. 24 / 100).
- user can see network logs in real time and filter them by both components: method or url.

2. Delete network logs
- user can delete network logs recorded until that moment.

3. Export network logs
- user can export network logs into text file on their local device or any folder in iCloud.

4. Simulate crash
- user can simulate crash to check if firebase integration works.

5. Display FCM push token
- user can see currently used FCM pushed token.


<b>AWLDebugTool settings</b>
1. User can define maximal number of logs for specific report, both standard (250, 500, 750, 100)
or custom (e.g. 15, 122, 800, ...)
2. User can define filename for network logs. By default, tool will create file with
current timestamp (e.g. NL2023-06-21T11:37:25.txt) or user can define its own filename.
3. Every change inside settings must be confirmed by click on toolbar button "Save and exit".
