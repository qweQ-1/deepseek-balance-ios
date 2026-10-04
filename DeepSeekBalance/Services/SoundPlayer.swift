import AVFoundation
import Foundation

/// 内置音效。
enum AppSound: String, CaseIterable {
    case pop   // 点小饭团
    case ding  // 检测到充值
    case eat   // 喂饭
}

protocol SoundPlaying {
    func play(_ sound: AppSound)
}

/// 播放内置音效；资源缺失时静默跳过（测试环境安全）。
final class SystemSoundPlayer: SoundPlaying {
    private var players: [AppSound: AVAudioPlayer] = [:]

    func play(_ sound: AppSound) {
        if let player = players[sound] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        player.prepareToPlay()
        players[sound] = player
        player.play()
    }
}
