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

/// 播放音效：优先用户自定义音效（SoundStore），否则播放内置音效。
/// 资源缺失时静默跳过（测试环境安全）。
final class SystemSoundPlayer: SoundPlaying {
    private var activePlayers: [AVAudioPlayer] = []

    func play(_ sound: AppSound) {
        let custom = SoundStore.shared.customURL(for: sound)
        let bundled = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
        guard let url = custom ?? bundled,
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.prepareToPlay()
        player.play()
        activePlayers = activePlayers.filter { $0.isPlaying }
        activePlayers.append(player)
    }
}
