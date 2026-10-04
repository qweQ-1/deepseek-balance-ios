import AVFoundation
import Foundation

/// 「保持后台运行」的抽象（方便测试替换）。
@MainActor
protocol BackgroundKeeping: AnyObject {
    func setKeepAlive(_ on: Bool)
}

/// 静音音频保活：让 App 在后台不被挂起（余额刷新/提醒/画中画继续工作）。
@MainActor
final class SilentAudioKeeper: BackgroundKeeping {
    private let token = "app-background"

    func setKeepAlive(_ on: Bool) {
        if on {
            BackgroundAudioSession.shared.hold(token)
        } else {
            BackgroundAudioSession.shared.release(token)
        }
    }
}

/// 共享的静音音频会话：所有持有者都释放后才真正停止（画中画与后台保活互不干扰）。
@MainActor
final class BackgroundAudioSession {
    static let shared = BackgroundAudioSession()

    private var holders: Set<String> = []
    private var player: AVAudioPlayer?

    func hold(_ token: String) {
        holders.insert(token)
        activateIfNeeded()
    }

    func release(_ token: String) {
        holders.remove(token)
        if holders.isEmpty {
            deactivate()
        }
    }

    private func activateIfNeeded() {
        guard player == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0.01
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    private func deactivate() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
