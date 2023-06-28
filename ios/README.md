DebugTool

DebugTool is in-house tool developed for easier app debugging in development process.
Main functionality is to follow network traffic that the app makes during usage.


Installation
Add DebugTool as Framework to project


Usage
1. add DebugTool to App.swift as ViewModifier

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


2. add DebugTool as singleton to code where requests are made and track them using "createNetworkLog()" method

import DebugTool

struct BaseLoader: Loader {
    let networkLogsService = DebugTool.NetworkLogsService.shared

    networkLogsService.createNetworkLog(method: method.rawValue, url: urlString)
}

3. open DebugTool inside app by clicking 10 times on HomeScreen View


Functionalities
1. Show network logs
User can see information about total number of logs (e.g. 24 / 100).
User can see network logs in real time and filter them by both components: method or url.

2. Delete network logs
User can delete network logs recorded until that moment.

3. Export network logs
User can export network logs into text file on their local device or any folder in iCloud.

4. Simualte Firebase crash
User can simulate crash to check if firebase integration works.

5. Display FCM push token
User can see currently used FCM pushed token


DebugTool settings
User can define maximal number of logs for specific report, both standard (250, 500, 750, 100)
or custom (e.g. 15, 122, 800, ...)
User can define filename for network logs. By default, tool will create file with
current timestamp (e.g. NL2023-06-21T11:37:25.txt) or user can define its own filename.

Every change inside settings must be confirmed by click on toolbar button "Save and exit".





