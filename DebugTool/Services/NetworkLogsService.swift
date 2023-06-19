//
//  NetworkLogsService.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 13.06.2023..
//

import Foundation

public class NetworkLogsService: ObservableObject {
    
    public static let shared = NetworkLogsService()
    private var url: URL = FileManager.documentsDirectory.appendingPathExtension(Constants.Defaults.defaultFilename)
    @Published var networkTraffic: [NetworkLog] = []
    
    @Published var areSettingsChanged = false
    @Published var standardLogLimit = Constants.Defaults.defaultLogLimit
    @Published var useCustomLogLimit = false
    @Published var customLogLimit = Constants.Defaults.defaultLogLimit
    @Published var logLimit = Constants.Defaults.defaultLogLimit
    
    @Published var useCustomFileName = false
    var customFileName = ""
    
    @Published var exporting = false
    @Published var document = TextDocument(text: "")
    
    private init() {
        print(Constants.Actions.initilize)
        configureDebugTool()
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
            customFileName = UserDefaults.standard.string(forKey: "customFilename") ?? Constants.Defaults.defaultFilename
            url = FileManager.documentsDirectory.appendingPathExtension("\(customFileName)")
        } else {
            let date = Date.now
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            url = FileManager.documentsDirectory.appendingPathExtension("NL\(df.string(from: date)).txt")
        }
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
        self.exporting = true
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
    }
    
    // MARK: - Settings
    func saveSettings() {
        print(Constants.Actions.savingSettings)
        
        UserDefaults.standard.set(useCustomLogLimit, forKey: Constants.UserDefaults.useCustomLogLimit)
        UserDefaults.standard.set(useCustomFileName, forKey: Constants.UserDefaults.useCustomFilename)
        
        if useCustomLogLimit {
            UserDefaults.standard.set(customLogLimit, forKey: Constants.UserDefaults.customLogLimit)
        } else {
            UserDefaults.standard.set(standardLogLimit, forKey: Constants.UserDefaults.standardLogLimit)
        }
        
        if useCustomFileName {
            UserDefaults.standard.set(customFileName, forKey: Constants.UserDefaults.customFilename)
        }
    }
}
