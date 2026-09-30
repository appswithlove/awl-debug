import Foundation
import QuartzCore
import UIKit

struct ReportingMetricSample {
    let timestampMillis: Int64
    var cpuPercent: Double?
    var ramBytes: UInt64?
    var batteryPercent: Int?
    var uiFreezeMs: Int?
}

/// Takes a sample every 5 s while the app is in the foreground, without the panel's monitors:
/// process CPU averaged over the interval and all cores, `phys_footprint`, battery level and the longest
/// main-thread stall, measured as the largest gap between display-link frames.
final class ReportingMetricsSampler {
    static let interval: TimeInterval = 5

    private let queue: DispatchQueue
    private let onSample: (ReportingMetricSample) -> Void
    private var timer: DispatchSourceTimer?
    private var lastCPUTime: TimeInterval = 0
    private var lastUptime: TimeInterval = 0
    private let frameGaps = FrameGapTracker()

    /// `onSample` runs on `queue`.
    init(queue: DispatchQueue, onSample: @escaping (ReportingMetricSample) -> Void) {
        self.queue = queue
        self.onSample = onSample
    }

    /// Call on `queue`.
    func start() {
        guard timer == nil else { return }
        lastCPUTime = Self.processCPUTime()
        lastUptime = ProcessInfo.processInfo.systemUptime
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.interval, repeating: Self.interval, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in self?.sample() }
        timer.resume()
        self.timer = timer
        let frameGaps = frameGaps
        DispatchQueue.main.async {
            frameGaps.start()
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
    }

    /// Call on `queue`.
    func stop() {
        timer?.cancel()
        timer = nil
        let frameGaps = frameGaps
        DispatchQueue.main.async {
            frameGaps.stop()
        }
    }

    private func sample() {
        let timestamp = ReportingJSON.millis(Date())
        let cpuTime = Self.processCPUTime()
        let uptime = ProcessInfo.processInfo.systemUptime
        let wall = uptime - lastUptime
        let cpuPercent = wall > 0
            ? (cpuTime - lastCPUTime) / wall * 100 / Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
            : nil
        lastCPUTime = cpuTime
        lastUptime = uptime
        let footprint = RAMMonitor.readAppMemory().footprint
        var sample = ReportingMetricSample(timestampMillis: timestamp,
                                           cpuPercent: cpuPercent.map { min(max($0, 0), 100) },
                                           ramBytes: footprint > 0 ? footprint : nil)
        let frameGaps = frameGaps
        let queue = queue
        // Read on the main thread; while it is frozen, the sample waits and then reports the freeze.
        DispatchQueue.main.async { [weak self] in
            // Battery monitoring can be switched off by the panel's battery monitor in the meantime.
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            sample.batteryPercent = level >= 0 ? Int((level * 100).rounded()) : nil
            sample.uiFreezeMs = frameGaps.takeLongestStallMs()
            queue.async {
                guard self?.timer != nil else { return }
                self?.onSample(sample)
            }
        }
    }

    /// User and system time of all threads of the process, including finished ones.
    static func processCPUTime() -> TimeInterval {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        func seconds(_ time: timeval) -> TimeInterval {
            TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000
        }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}

/// Measures main-thread stalls as gaps between display-link callbacks beyond one frame. Main thread only.
final class FrameGapTracker: NSObject {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var longestStall: CFTimeInterval?
    private var frameDuration: CFTimeInterval?

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // A low rate keeps ProMotion displays from running at 120 Hz for us; stalls are still measured in full.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = nil
        longestStall = nil
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    /// Longest stall in ms since the last call, `nil` before the first frame. A stall that has just ended
    /// counts here even if no frame followed it yet; the next frame then only measures from now.
    func takeLongestStallMs(now: CFTimeInterval = CACurrentMediaTime()) -> Int? {
        defer { longestStall = nil }
        if let lastTimestamp, let frameDuration {
            longestStall = max(longestStall ?? 0, now - lastTimestamp - frameDuration, 0)
            self.lastTimestamp = max(lastTimestamp, now)
        }
        return longestStall.map { Int(($0 * 1000).rounded()) }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let frameDuration = link.targetTimestamp - link.timestamp
        if let lastTimestamp {
            let stall = max(link.timestamp - lastTimestamp - frameDuration, 0)
            longestStall = max(longestStall ?? 0, stall)
        }
        lastTimestamp = max(lastTimestamp ?? 0, link.timestamp)
        self.frameDuration = frameDuration
    }
}
