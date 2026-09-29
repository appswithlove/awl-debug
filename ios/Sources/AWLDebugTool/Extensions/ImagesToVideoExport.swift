//
//  ImagesToVideoExport.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 15.09.2025.
//

import AVFoundation
import UIKit

enum ImagesToVideoExport {
    struct Failure: Error {}

    static let maxLongEdge: CGFloat = 1280
    /// Enough for sharp text at 3 fps: an iPhone screen at scale 1 comes to about 4 MB per minute.
    private static let bitsPerPixel: Double = 0.5

    /// `frameSize` fitted into `maxLongEdge`, times `scale`, rounded down to even pixels as H.264 needs them.
    static func videoSize(for frameSize: CGSize, scale: CGFloat = 1) -> CGSize {
        let longEdge = max(frameSize.width, frameSize.height)
        guard longEdge > 0 else {
            return .zero
        }
        let factor = min(1, maxLongEdge / longEdge) * scale
        func even(_ value: CGFloat) -> CGFloat {
            max(2, (value * factor / 2).rounded(.down) * 2)
        }
        return CGSize(width: even(frameSize.width), height: even(frameSize.height))
    }

    /// Writes the images as an H.264 MP4 of `size`, one image per frame at `fps`, in the given order. Images of another
    /// size or orientation are fitted in on black. Unreadable images are left out; throws when none is written.
    static func createVideo(from imageUrls: [URL], size: CGSize, fps: Int, outputURL: URL) async throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        // `moov` in front, so browsers start playing before the whole file is loaded.
        writer.shouldOptimizeForNetworkUse = true
        let width = Int(size.width)
        let height = Int(size.height)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(Double(width * height * fps) * bitsPerPixel),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps * 10,
                AVVideoAllowFrameReorderingKey: false,
            ] as [String: Any],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else {
            throw Failure()
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? Failure()
        }
        writer.startSession(atSourceTime: .zero)

        let written = await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            var index = 0
            var written: Int64 = 0
            var isDone = false
            input.requestMediaDataWhenReady(on: DispatchQueue(label: "com.appswithlove.debug.video")) {
                while !isDone, input.isReadyForMoreMediaData {
                    guard index < imageUrls.count, writer.status == .writing else {
                        isDone = true
                        input.markAsFinished()
                        continuation.resume(returning: written)
                        return
                    }
                    let url = imageUrls[index]
                    index += 1
                    autoreleasepool {
                        guard let image = UIImage(contentsOfFile: url.path)?.cgImage,
                              let pool = adaptor.pixelBufferPool,
                              let buffer = pixelBuffer(from: image, pool: pool, size: size) else {
                            return
                        }
                        if adaptor.append(buffer, withPresentationTime: CMTime(value: written, timescale: CMTimeScale(fps))) {
                            written += 1
                        }
                    }
                }
            }
        }
        await writer.finishWriting()
        guard writer.status == .completed, written > 0 else {
            try? FileManager.default.removeItem(at: outputURL)
            throw writer.error ?? Failure()
        }
    }

    private static func pixelBuffer(from image: CGImage, pool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(image, in: aspectFit(CGSize(width: image.width, height: image.height), in: size))
        return buffer
    }

    /// `content` scaled to fit `bounds`, centred.
    static func aspectFit(_ content: CGSize, in bounds: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0 else {
            return CGRect(origin: .zero, size: bounds)
        }
        let factor = min(bounds.width / content.width, bounds.height / content.height)
        let size = CGSize(width: content.width * factor, height: content.height * factor)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}
