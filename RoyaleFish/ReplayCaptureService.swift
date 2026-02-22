//
//  ReplayCaptureService.swift
//  RoyaleFish
//
//  Created by Benjamin Duboshinsky on 2/21/26.
//

import Foundation
import ReplayKit
import UIKit
import AVFoundation

final class ReplayCaptureService {
    enum CaptureError: Error { case notAvailable, badBuffer }

    private let recorder = RPScreenRecorder.shared()
    private var startedAt = Date()

    // throttle sending frames
    private var lastSentAt: TimeInterval = 0

    func startCapture(
        framesPerMinute: Double,
        onFrame: @escaping (_ jpegData: Data, _ timestamp: Double) -> Void
    ) async throws {
        guard recorder.isAvailable else { throw CaptureError.notAvailable }

        startedAt = Date()
        lastSentAt = 0

        let minInterval = max(60.0 / max(framesPerMinute, 1), 0.2) // don’t spam
        try await recorder.startCapture(handler: { [weak self] sample, bufferType, error in
            guard let self else { return }
            if let _ = error { return }

            guard bufferType == .video else { return }

            let now = Date()
            let ts = now.timeIntervalSince(self.startedAt)

            // throttle
            if ts - self.lastSentAt < minInterval { return }
            self.lastSentAt = ts

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)

            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage)

            // compress to jpeg (small)
            guard let jpeg = uiImage.jpegData(compressionQuality: 0.55) else { return }
            onFrame(jpeg, ts)
        })
    }

    func stopCapture() async {
        recorder.stopCapture { _ in }
    }
}
