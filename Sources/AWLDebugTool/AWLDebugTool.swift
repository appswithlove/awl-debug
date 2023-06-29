import Foundation
import SwiftUI

public class AWLDebugTool: ObservableObject {
    
    public static let shared = AWLDebugTool()
    private var url: URL = FileManager.documentsDirectory.appendingPathExtension(Constants.Defaults.defaultUrlFilename)
    @Published var networkTraffic: [NetworkLog] = []
    
    @Published var areSettingsChanged = false
    @Published var standardLogLimit = Constants.Defaults.defaultLogLimit
    @Published var useCustomLogLimit = false
    @Published var customLogLimit = Constants.Defaults.defaultLogLimit
    @Published var logLimit = Constants.Defaults.defaultLogLimit
    
    @Published var filename = Constants.Strings.unknownValue
    @Published var useCustomFileName = false
    var customFileName = Constants.Strings.unknownValue
    var standardFileName = Constants.Strings.unknownValue
    
    @Published var isShowingDeleteNetworkLogs = false
    @Published var isShowingFileExporter = false
    @Published var document = TextDocument(text: Constants.Strings.unknownValue)
    
    private init() {
        print(Constants.Logs.initilize)
        displaySettings()
        configureDebugTool()
        displaySettings()
    }
    
    // MARK: - Configuration
    private func configureDebugTool() {
        print(Constants.Logs.configureDT)
        configureLogLimit()
        configureFileName()
    }
    
    private func configureLogLimit() {
        useCustomLogLimit = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomLogLimit)
        if useCustomLogLimit {
            customLogLimit = UserDefaults.standard.integer(forKey: Constants.UserDefaults.customLogLimit)
            if customLogLimit == 0 {
                customLogLimit = Constants.Defaults.defaultLogLimit
            }
            logLimit = customLogLimit
        } else {
            customLogLimit = Constants.Defaults.defaultLogLimit
            UserDefaults.standard.set(customLogLimit, forKey: Constants.UserDefaults.customLogLimit)

            standardLogLimit = UserDefaults.standard.integer(forKey: Constants.UserDefaults.standardLogLimit)
            if standardLogLimit == 0 {
                standardLogLimit = Constants.Defaults.defaultLogLimit
            }
            logLimit = standardLogLimit
        }
    }
    
    private func configureFileName() {
        filename = createStandardFilename()
        standardFileName = filename
        UserDefaults.standard.set(standardFileName, forKey: Constants.UserDefaults.standardFilename)

        useCustomFileName = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomFilename)
        if useCustomFileName {
            customFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.customFilename) ?? Constants.Defaults.defaultFilename
            filename = customFileName
        }
    }
    
    private func createStandardFilename() -> String {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = Constants.Date.dateFormat
        return "NL\(df.string(from: date))"
    }
    
    // MARK: - Network logs
    public func createNetworkLog(method: String, url: String) {
        print(Constants.Logs.creatingNL)
        if checkLogLimit() {
            let log = NetworkLog(id: UUID(), method: method, url: url)
            networkTraffic.append(log)
            saveNetworkLogs()
        }
    }
    
    private func checkLogLimit() -> Bool {
        return networkTraffic.count < logLimit ? true : false
    }
    
    func loadNetworkLogs() {
        do {
            print(Constants.Logs.loadingNL)
            let data = try Data(contentsOf: url)
            networkTraffic = try JSONDecoder().decode([NetworkLog].self, from: data)
        } catch {
            networkTraffic = []
        }
    }
    
    func deleteNetworkLogs() {
        print(Constants.Logs.deletingNL)
        networkTraffic = []
        saveNetworkLogs()
    }
    
    private func saveNetworkLogs() {
        do {
            print(Constants.Logs.savingNL)
            let data = try JSONEncoder().encode(networkTraffic)
            try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print(Constants.Errors.savingDataToFile)
        }
    }
    
    func exportNetworkLogs() {
        print(Constants.Logs.exportingNL)
        document.text = fetchNetworkLogsAsString()
        self.isShowingFileExporter = true
    }
    
    private func fetchNetworkLogsAsString() -> String {
        var result = ""
        for log in networkTraffic {
            let logAsString = "\(log.method) \(log.url)\n"
            result += logAsString
        }
        return result
    }
    
    func refreshData() {
        useCustomLogLimit = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomLogLimit)
        useCustomFileName = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomFilename)
        customLogLimit = UserDefaults.standard.integer(forKey: Constants.UserDefaults.customLogLimit)
        customFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.customFilename) ?? Constants.Defaults.defaultFilename
        standardFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.standardFilename) ?? Constants.Defaults.defaultFilename
    }
    
    // MARK: - Settings
    func saveSettings() {
        print(Constants.Logs.savingSettings)
        
        UserDefaults.standard.set(useCustomLogLimit, forKey: Constants.UserDefaults.useCustomLogLimit)
        UserDefaults.standard.set(useCustomFileName, forKey: Constants.UserDefaults.useCustomFilename)
        
        if useCustomLogLimit {
            UserDefaults.standard.set(customLogLimit, forKey: Constants.UserDefaults.customLogLimit)
            logLimit = customLogLimit
        } else {
            UserDefaults.standard.set(standardLogLimit, forKey: Constants.UserDefaults.standardLogLimit)
            logLimit = standardLogLimit
        }
        
        refreshNetworkTraffic()
        
        if useCustomFileName {
            filename = customFileName
            UserDefaults.standard.set(customFileName, forKey: Constants.UserDefaults.customFilename)
        } else {
            filename = UserDefaults.standard.string(forKey: Constants.UserDefaults.standardFilename) ?? Constants.Defaults.defaultFilename
        }
        
        displaySettings()
    }
    
    private func refreshNetworkTraffic() {
        var counter = networkTraffic.count - 1
        repeat {
            if counter >= logLimit {
                networkTraffic.remove(at: counter)
            }
            counter -= 1
        } while (counter >= logLimit)
        saveNetworkLogs()
    }

    func simulateCrashExplicitly() {
        fatalError(Constants.Strings.fatalErrorMsg)
    }

    func simulateCrashImplicitly() {
        var testArray: [Int] = []
        _ = testArray.removeFirst()
        _ = 1 / testArray.count
    }

    // MARK: - Helpers
    func displaySettings() {
        print("-----------------------------------------------")
        print("Url: \(url.lastPathComponent)")
        print("Use custom log limit: \(useCustomLogLimit)")
        print("Log limit: \(logLimit)")
        print("Standard log limit: \(standardLogLimit)")
        print("Custom log limit: \(customLogLimit)")
        print("Use custom filename: \(useCustomFileName)")
        print("Filename: \(filename)")
        print("Standard filename: \(standardFileName)")
        print("Custom filename: \(customFileName)")
        print("-----------------------------------------------")
    }
}
