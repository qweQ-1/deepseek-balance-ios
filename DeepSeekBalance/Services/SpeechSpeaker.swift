import AVFoundation
import Foundation

protocol SpeechSpeaking {
    func speak(_ text: String)
}

/// 用系统语音合成朗读台词（中文）。
final class SystemSpeechSpeaker: SpeechSpeaking {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.15
        synthesizer.speak(utterance)
    }
}
