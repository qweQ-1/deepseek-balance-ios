import AVFoundation
import AVKit
import CoreMedia
import CoreVideo
import Foundation
import SwiftUI
import UIKit

/// 画中画余额窗的抽象（方便测试替换）。
@MainActor
protocol PiPDisplaying: AnyObject {
    var isActive: Bool { get }
    func start(text: String)
    func update(text: String)
    func stop()
}

/// 用 AVSampleBufferDisplayLayer + AVPictureInPictureController 把余额渲染进 PiP 小窗；
/// 静音音频保活，使 PiP 激活期间 App 能继续在后台定时刷新余额。
@MainActor
final class BalancePiPController: NSObject, PiPDisplaying {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var layerHostView: UIView?
    private var silentPlayer: AVAudioPlayer?

    private(set) var isActive = false
    /// 期望处于激活状态；启动失败时据此决定是否重试。
    private var wantsToBeActive = false
    private var startRetryBudget = 0

    func start(text: String) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        wantsToBeActive = true
        startRetryBudget = 0
        attachLayerToWindowIfNeeded()
        activateBackgroundAudio()
        ensureController()
        render(text: text)
        attemptStart(retries: 4)
    }

    func update(text: String) {
        guard isActive else { return }
        render(text: text)
    }

    func stop() {
        wantsToBeActive = false
        pipController?.stopPictureInPicture()
        if !isActive {
            deactivateBackgroundAudio()
        }
    }

    // MARK: - 启动与重试

    /// 尝试启动 PiP；系统还没就绪时短暂重试（切后台的瞬间通常要等一个节拍）。
    private func attemptStart(retries: Int) {
        guard wantsToBeActive, let pipController else { return }
        if pipController.isPictureInPictureActive || isActive { return }

        if pipController.isPictureInPicturePossible {
            NSLog("[PiP] startPictureInPicture()")
            pipController.startPictureInPicture()
            return
        }

        guard retries > 0, startRetryBudget < 12 else {
            NSLog("[PiP] give up: isPictureInPicturePossible == false")
            return
        }
        startRetryBudget += 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.attemptStart(retries: retries - 1)
        }
    }

    private func retryAfterFailure() {
        guard wantsToBeActive, startRetryBudget < 12 else {
            deactivateBackgroundAudio()
            return
        }
        startRetryBudget += 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.attemptStart(retries: 1)
        }
    }

    // MARK: - 内部

    private func ensureController() {
        guard pipController == nil else { return }
        displayLayer.videoGravity = .resizeAspect
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
    }

    /// 把显示层挂进当前窗口（2×2 不可见；样本缓冲 PiP 要求层在视图层级里渲染）。
    private func attachLayerToWindowIfNeeded() {
        guard layerHostView == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window else { return }
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        host.isUserInteractionEnabled = false
        displayLayer.frame = host.bounds
        host.layer.addSublayer(displayLayer)
        window.addSubview(host)
        layerHostView = host
    }

    private func activateBackgroundAudio() {
        guard silentPlayer == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0.01
        player.prepareToPlay()
        player.play()
        silentPlayer = player
    }

    private func deactivateBackgroundAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func render(text: String) {
        let renderer = ImageRenderer(content: PiPBalanceView(text: text))
        renderer.scale = 2
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage,
              let pixelBuffer = Self.makePixelBuffer(from: cgImage),
              let sampleBuffer = Self.makeSampleBuffer(from: pixelBuffer) else { return }
        if displayLayer.requiresFlushToResumeDecoding {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    private static func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(
                  data: base,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private static func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard bufferStatus == noErr, let sampleBuffer else { return nil }
        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension BalancePiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
        startRetryBudget = 0
        NSLog("[PiP] did start")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        wantsToBeActive = false
        deactivateBackgroundAudio()
        NSLog("[PiP] did stop")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        NSLog("[PiP] failed to start: %@", String(describing: error))
        retryAfterFailure()
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension BalancePiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

/// 渲染进 PiP 小窗的余额画面。
struct PiPBalanceView: View {
    let text: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.deepSeekBlue, Color.deepSeekBlueLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Text("🐋 DeepSeek 余额")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(text)
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("小饭团守护中 · 回 App 看详情")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
        }
        .frame(width: 480, height: 300)
    }
}
