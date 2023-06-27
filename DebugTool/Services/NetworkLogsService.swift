//
//  NetworkLogsService.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 13.06.2023..
//

import Foundation

public class NetworkLogsService: ObservableObject {
    
    public static let shared = NetworkLogsService()
    private var url: URL = FileManager.documentsDirectory.appendingPathExtension(Constants.Defaults.defaultUrlFilename)
    @Published var networkTraffic: [NetworkLog] = []
    
    @Published var areSettingsChanged = false
    @Published var standardLogLimit = Constants.Defaults.defaultLogLimit
    @Published var useCustomLogLimit = false
    @Published var customLogLimit = Constants.Defaults.defaultLogLimit
    @Published var logLimit = Constants.Defaults.defaultLogLimit
    
    @Published var filename = Constants.Strings.unknown
    @Published var useCustomFileName = false
    var customFileName = Constants.Strings.unknown
    var standardFileName = Constants.Strings.unknown
    
    @Published var isShowingFileExporter = false
    @Published var document = TextDocument(text: Constants.Strings.unknown)
    
    private init() {
        print(Constants.Actions.initilize)
        displaySettings()
        configureDebugTool()
        displaySettings()
    }
    
    // MARK: - Configuration
    private func configureDebugTool() {
        print(Constants.Actions.configureDT)
        configureLogLimit()
        configureFileName()
    }
    
    private func configureLogLimit() {
        useCustomLogLimit = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomLogLimit)
        if useCustomLogLimit {
            customLogLimit = UserDefaults.standard.integer(forKey: Constants.UserDefaults.customLogLimit)
            logLimit = customLogLimit
        } else {
            standardLogLimit = UserDefaults.standard.integer(forKey: Constants.UserDefaults.standardLogLimit)
            if standardLogLimit == 0 {
                standardLogLimit = Constants.Defaults.defaultLogLimit
            }
            logLimit = standardLogLimit
        }
    }
    
    private func configureFileName() {
        useCustomFileName = UserDefaults.standard.bool(forKey: Constants.UserDefaults.useCustomFilename)
        if useCustomFileName {
            customFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.customFilename) ?? Constants.Strings.unknown
            filename = customFileName
        } else {
            standardFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.standardFilename) ?? Constants.Strings.unknown
            filename = createStandardFilename()
        }
    }
    
    private func createStandardFilename() -> String {
        let date = Date.now
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return "NL\(df.string(from: date))"
    }
    
    // MARK: - Network logs
    public func createNetworkLog(method: String, url: String) {
        print(Constants.Actions.creatingNL)
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
            print(Constants.Actions.loadingNL)
            let data = try Data(contentsOf: url)
            networkTraffic = try JSONDecoder().decode([NetworkLog].self, from: data)
        } catch {
            networkTraffic = []
        }
    }
    
    func deleteNetworkLogs() {
        print(Constants.Actions.deletingNL)
        networkTraffic = []
        saveNetworkLogs()
    }
    
    private func saveNetworkLogs() {
        do {
            print(Constants.Actions.savingNL)
            let data = try JSONEncoder().encode(networkTraffic)
            try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print(Constants.Errors.savingDataToFile)
        }
    }
    
    func exportNetworkLogs() {
        print(Constants.Actions.exportingNL)
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
        customFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.customFilename) ?? Constants.Strings.unknown
        standardFileName = UserDefaults.standard.string(forKey: Constants.UserDefaults.standardFilename) ?? Constants.Strings.unknown
    }
    
    // MARK: - Settings
    func saveSettings() {
        print(Constants.Actions.savingSettings)
        
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
            UserDefaults.standard.set(customFileName, forKey: Constants.UserDefaults.customFilename)
            filename = customFileName
        } else {
            UserDefaults.standard.set(customFileName, forKey: Constants.UserDefaults.standardFilename)
            filename = standardFileName
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

    func doTestCrash1() {
        fatalError("Don't worry be happy.")
    }

    func doTestCrash2() {
        var testArray: [Int] = []
        _ = testArray.removeFirst()
        _ = 1 / testArray.count
    }

    // MARK: - Helpers
    func displaySettings() {
        print("DT - Url: \(url)")
        print("DT - use custom filename: \(useCustomFileName)")
        print("DT - use custom log limit: \(useCustomLogLimit)")
        print("DT - Filename: \(filename)")
        print("DT - Custom filename: \(customFileName)")
        print("DT - Log limit: \(logLimit)")
        print("DT - Custom log limit: \(customLogLimit)")
    }
}
