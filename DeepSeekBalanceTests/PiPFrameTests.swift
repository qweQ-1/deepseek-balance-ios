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
        var sawBright = false
        var sawBluish = false
        for y in stride(from: 4, to: height, by: 30) {
            for x in stride(from: 4, to: width, by: 30) {
                let offset = y * bytesPerRow + x * 4
                sampled += 1
                let b = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let r = Int(bytes[offset + 2])
                let a = Int(bytes[offset + 3])
                if a > 200 { opaqueCount += 1 }
                if a > 200 && r + g + b > 300 { sawBright = true }
                if a > 200 && b > 120 && b > r + 30 { sawBluish = true }
            }
        }
        #expect(sampled > 200)
        #expect(opaqueCount >= sampled - 2, "帧内容应基本不透明（实际 \(opaqueCount)/\(sampled)）")
        #expect(sawBright, "帧里应有亮色内容（文字）")
        #expect(sawBluish, "帧里应有品牌蓝背景")
    }

    @Test func rendersDifferentTexts() throws {
        let first = try #require(PiPFrameRenderer.renderSampleBuffer(text: "¥1.00"))
        let second = try #require(PiPFrameRenderer.renderSampleBuffer(text: "¥9999.99"))
        #expect(CMSampleBufferGetNumSamples(first) == 1)
        #expect(CMSampleBufferGetNumSamples(second) == 1)
    }
}
