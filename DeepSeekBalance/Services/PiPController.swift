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

/// 把余额文本渲染成 PiP 用的视频帧（可单测）。
@MainActor
enum PiPFrameRenderer {
    static func renderSampleBuffer(text: String, scale: CGFloat = 2) -> CMSampleBuffer? {
        let renderer = ImageRenderer(content: PiPBalanceView(text: text))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage,
              let pixelBuffer = makePixelBuffer(from: cgImage),
              let sampleBuffer = makeSampleBuffer(from: pixelBuffer) else { return nil }
        return sampleBuffer
    }

    static func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
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

    static func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
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

        // 标记“立即显示”（实时内容），让 PiP 窗口马上能看到画面。
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0,
           let raw = CFArrayGetValueAtIndex(attachments, 0) {
            let dict = Unmanaged<CFMutableDictionary>.fromOpaque(raw).takeUnretainedValue()
            if let value = kCFBooleanTrue {
                CFDictionarySetValue(
                    dict,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                    Unmanaged.passUnretained(value).toOpaque()
                )
            }
        }
        return sampleBuffer
    }
}

/// 用 AVSampleBufferDisplayLayer + AVPictureInPictureController 把余额渲染进 PiP 小窗；
/// 静音音频保活 + 每秒续投帧，使小窗在后台持续显示。
@MainActor
final class BalancePiPController: NSObject, PiPDisplaying {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var layerHostView: UIView?
    private var pumpTask: Task<Void, Never>?

    private(set) var isActive = false
    /// 期望处于激活状态；启动失败时据此决定是否重试。
    private var wantsToBeActive = false
    private var startRetryBudget = 0
    private var latestText = ""

    func start(text: String) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        wantsToBeActive = true
        startRetryBudget = 0
        latestText = text
        BackgroundAudioSession.shared.hold("pip")
        attachLayerToWindowIfNeeded()
        ensureController()
        enqueueFrame()
        startPump()
        attemptStart(retries: 4)
    }

    func update(text: String) {
        latestText = text
        guard isActive else { return }
        enqueueFrame()
    }

    func stop() {
        wantsToBeActive = false
        pipController?.stopPictureInPicture()
        stopPump()
        BackgroundAudioSession.shared.release("pip")
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
            stopPump()
            BackgroundAudioSession.shared.release("pip")
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
            stopPump()
            BackgroundAudioSession.shared.release("pip")
            return
        }
        startRetryBudget += 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.attemptStart(retries: 1)
        }
    }

    // MARK: - 投帧

    /// 每秒续投一帧（即使画面没变），让 PiP 认为视频仍在播放、持续显示画面。
    private func startPump() {
        pumpTask?.cancel()
        pumpTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.wantsToBeActive || self.isActive else { return }
                self.enqueueFrame()
            }
        }
    }

    private func stopPump() {
        pumpTask?.cancel()
        pumpTask = nil
    }

    private func enqueueFrame() {
        guard let sampleBuffer = PiPFrameRenderer.renderSampleBuffer(text: latestText) else {
            NSLog("[PiP] render failed")
            return
        }
        if displayLayer.status == .failed || displayLayer.requiresFlushToResumeDecoding {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
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

    /// 把显示层挂进窗口最底层（被页面内容盖住、用户不可见，但仍在渲染）。
    private func attachLayerToWindowIfNeeded() {
        guard layerHostView == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window else { return }
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        host.isUserInteractionEnabled = false
        displayLayer.frame = host.bounds
        host.layer.addSublayer(displayLayer)
        window.insertSubview(host, at: 0)
        layerHostView = host
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension BalancePiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
        startRetryBudget = 0
        enqueueFrame()
        NSLog("[PiP] did start")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        wantsToBeActive = false
        stopPump()
        BackgroundAudioSession.shared.release("pip")
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
