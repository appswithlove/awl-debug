//
//  ScreenRecorder.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 15.09.2025.
//

import SwiftUI
import UIKit

extension ScreenRecorder {
    static let shared = ScreenRecorder()
    
    func start(duration: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if let window = UIApplication.shared.getKeyWindow {
                UIWindow.swizzleSendEvent()
                self.startCapturing(from: window, fps: 3, duration: duration)
            }
        })
    }
    
    func stop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            self.stopCapturing()
        })
    }
    
    func exportLastVideo(completion: @escaping () -> Void) {
        exportVideo(folder: lastScreenRecordingFolder, completion: completion)
    }
    
    func exportCurrentVideo(completion: @escaping () -> Void) {
        exportVideo(folder: currentScreenRecordingFolder, completion: completion)
    }
}

extension ScreenRecorder {
    enum TouchPhase: String {
        case began
        case moved
        case ended
        case other
    }
    
    struct TouchEvent {
        let id: String
        let center: CGPoint
        let phase: TouchPhase
    }
}

class ScreenRecorder {
    private let hardworkingQueue = DispatchQueue(label: "com.awl.debugtool.ScreenRecorder", qos: .background)
    
    private var lastTouchDate = Date()
    private var touches: [TouchEvent] = []
    private var lastScreenshot: UIImage?
    private let activeRecordTime: TimeInterval = 1
    private var afterActivePeriodScreenshotsCount = 0
    private let afterActivePeriodScreenshotsMin = 2
    
    private var currentFrameIndexes: [Int] = []
    
    private var bufferTime = 10
    private var bufferFPS = 10
    
    private var timer: Timer?
    
    private init() {
        saveCurrentToLast()
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidUpdatedNotification),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidUpdatedNotification),
                                               name: UIResponder.keyboardDidHideNotification, object: nil)
    }
    
    @objc private func keyboardDidUpdatedNotification() {
        if lastScreenshot != nil { // isStated
            self.lastTouchDate = Date()
            self.afterActivePeriodScreenshotsCount = 0
            self.updateTmpFile {}
        }
    }
    
    @objc private func orientationDidUpdatedNotification() {
        if lastScreenshot != nil { // isStated
            self.lastTouchDate = Date()
            self.afterActivePeriodScreenshotsCount = 0
            self.updateTmpFile {}
        }
    }
    
    func addTouch(id: String, center: CGPoint, phase: TouchPhase) {
        if lastScreenshot != nil { // isStated
            self.lastTouchDate = Date()
            self.afterActivePeriodScreenshotsCount = 0
            touches.append(TouchEvent(id: id, center: center, phase: phase))
            if touches.count == 1 {
                self.updateTmpFile {}
            }
        }
    }
    
    private func cleanTouches() {
        var handledTouchIds = Set<String>()
        for i in (0..<touches.count).reversed() {
            let touch = touches[i]
            if handledTouchIds.contains(touch.id) {
                touches.remove(at: i)
            } else {
                handledTouchIds.insert(touch.id)
                if touch.phase == .ended {
                    touches.remove(at: i)
                }
            }
        }
    }
    
    private func startCapturing(from window: UIWindow?, fps: Int = 2, duration: Int = 30) {
        bufferFPS = min(30, fps)
        bufferTime = max(5, duration)
        lastTouchDate = Date()
        self.afterActivePeriodScreenshotsCount = 0
        stopCapturing()
        guard let window = window else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1 / TimeInterval(bufferFPS), repeats: true) { _ in
            let isActiveRecordPeriod = self.lastTouchDate.addingTimeInterval(self.activeRecordTime) > Date()
            if isActiveRecordPeriod || self.afterActivePeriodScreenshotsCount < self.afterActivePeriodScreenshotsMin || !self.touches.isEmpty {
                if !isActiveRecordPeriod {
                    self.afterActivePeriodScreenshotsCount += 1
                }

                self.updateTmpFile {
                    self.storeTmpFile()
                    self.lastScreenshot = window.captureScreenshot()
                }
                self.cleanTouches()
            }
        }
        
//        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopCapturing() {
        touches = []
        lastScreenshot = nil
        timer?.invalidate()
        timer = nil
    }
    
}

private extension ScreenRecorder {
    var rootFolder: URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AWLDebugTool")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    
    var lastScreenRecordingFolder: URL {
        let folder = rootFolder.appendingPathComponent("lastScreenRecording")
        return folder
    }
    
    var currentScreenRecordingFolder: URL {
        let folder = rootFolder.appendingPathComponent("currentScreenRecording")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    
    func fileName(index: Int) -> String {
        return "\(index).jpeg"
    }
    
    func fileUrl(index: Int) -> URL {
        currentScreenRecordingFolder.appendingPathComponent(fileName(index: index))
    }
    
    func index(date: Date?) -> Int {
        return Int((date?.timeIntervalSince1970 ?? 0) * 1000)
    }
    
    func saveCurrentToLast() {
        try? FileManager.default.removeItem(at: lastScreenRecordingFolder)
        try? FileManager.default.moveItem(at: currentScreenRecordingFolder, to: lastScreenRecordingFolder)
    }
    
    func allImageIndexes(folder: URL) -> [Int] {
        let fileURLs = try? FileManager.default.contentsOfDirectory(at: folder,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])
        
        var fileIndexes: [Int] = fileURLs?.compactMap({
            let fileName = $0.lastPathComponent
            let components = fileName.components(separatedBy: ".")
            if components.count == 2 && components.last == "jpeg", let index = Int(components[0]) {
                return index
            } else {
                return nil
            }
        }).sorted() ?? []
        
        if fileIndexes.first == 0 {
            fileIndexes.remove(at: 0)
            fileIndexes.append(0)
        }
        
        return fileIndexes
    }
    
    func storeTmpFile() {
        let tmpFrameIndex = index(date: nil)
        let newFrameIndex = index(date: .now)
        currentFrameIndexes.append(newFrameIndex)
        
        var toDelete: [Int] = []
        while currentFrameIndexes.count > bufferFPS * bufferTime {
            let i = 0
            toDelete.append( currentFrameIndexes.remove(at: i) )
        }
        
        hardworkingQueue.async {
            try? FileManager.default.moveItem(at: self.fileUrl(index: tmpFrameIndex), to: self.fileUrl(index: newFrameIndex))
            for index in toDelete {
                try? FileManager.default.removeItem(at: self.fileUrl(index: index))
            }
        }
    }
    
    func updateTmpFile(completion: @escaping () -> Void) {
        let touches = self.touches
        if let lastScreenshot = self.lastScreenshot {
            hardworkingQueue.async {
                let screenshotWithTouches = lastScreenshot.imageByDrawingCircles(
                    touches.map { touch -> UIImage.DrawingCircle in
                        UIImage.DrawingCircle(center: touch.center,
                                              radius: touch.phase == .began ? 20 : 15,
                                              fill: .brown.withAlphaComponent(0.3),
                                              stroke: { switch touch.phase {
                                              case .began: return .green
                                              case .moved: return nil
                                              case .ended: return .red
                                              case .other: return .yellow
                                              } }(),
                                              lineWidth: 3)
                    }
                )
                
                let tmpFrameIndex = self.index(date: nil)
                try? screenshotWithTouches.jpegData(compressionQuality: 0.8)?.write(to: self.fileUrl(index: tmpFrameIndex))
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
    func exportVideo(folder: URL, completion: @escaping () -> Void) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let dateString = formatter.string(from: .now)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("awl_debug_tool_\(dateString).mp4")
        try? FileManager.default.removeItem(at: tempURL)
        
        let indexes = allImageIndexes(folder: folder)
        let imagesUrls = indexes.map { folder.appendingPathComponent(fileName(index: $0)) }
        guard !imagesUrls.isEmpty, let firstFrameImage = UIImage(contentsOfFile: imagesUrls.last?.pathSafe ?? "") else {
            completion()
            return
        }
        
        let size = firstFrameImage.size
        let bufferFPS = self.bufferFPS
        DispatchQueue.global(qos: .userInitiated).async {
            createVideo(from: imagesUrls, size: size, fps: bufferFPS, outputURL: tempURL, completion: { success in
                DispatchQueue.main.async {
                    if success {
                        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                        UIViewController.topMostViewController()?.present(activityVC, animated: true)
                    }
                    completion()
                }
            })
        }
    }
}

// MARK: - helpers

private extension UIWindow {
    func captureScreenshot() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: bounds.size.width, height: bounds.size.height), format: format)
        return renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
    }
}
