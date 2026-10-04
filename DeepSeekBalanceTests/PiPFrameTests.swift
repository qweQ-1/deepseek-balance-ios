import AVFoundation
import CoreMedia
import CoreVideo
import Testing
@testable import DeepSeekBalance

@MainActor
@Suite struct PiPFrameTests {
    @Test func rendersNonEmptyFrame() throws {
        let sample = try #require(PiPFrameRenderer.renderSampleBuffer(text: "¥46.29"))
        #expect(CMSampleBufferGetNumSamples(sample) == 1)

        let buffer = try #require(CMSampleBufferGetImageBuffer(sample))
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        #expect(width == 960)
        #expect(height == 600)

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try #require(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)

        var opaqueCount = 0
        var sampled = 0
        for y in stride(from: 4, to: height, by: 60) {
            for x in stride(from: 4, to: width, by: 60) {
                let offset = y * bytesPerRow + x * 4
                sampled += 1
                if bytes[offset + 3] > 200 { opaqueCount += 1 }
            }
        }
        #expect(sampled > 50)
        #expect(opaqueCount >= sampled - 2, "帧内容应基本不透明（实际 \(opaqueCount)/\(sampled)）")
    }

    @Test func rendersDifferentTexts() throws {
        let first = try #require(PiPFrameRenderer.renderSampleBuffer(text: "¥1.00"))
        let second = try #require(PiPFrameRenderer.renderSampleBuffer(text: "¥9999.99"))
        #expect(CMSampleBufferGetNumSamples(first) == 1)
        #expect(CMSampleBufferGetNumSamples(second) == 1)
    }
}
