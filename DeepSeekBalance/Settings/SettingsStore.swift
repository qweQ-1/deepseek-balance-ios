import Foundation
import Observation

/// 设置的持久化后端；UserDefaults 直接可用，测试用内存版。
protocol SettingsBackend: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsBackend {}

/// 用户偏好设置（音效、语音、台词、提醒、定时刷新），改动自动持久化。
@MainActor
@Observable
final class SettingsStore {
    struct RefreshOption: Identifiable, Hashable {
        let label: String
        let seconds: Int
        var id: Int { seconds }
    }

    static let defaultSpeechLines = [
        "饿饿，饭饭！",
        "小饭团在守护你的余额～",
        "今天也要省着点用哦",
        "摸摸头，余额会变多的",
        "饭饭香香，余额旺旺",
    ]

    static let refreshOptions: [RefreshOption] = [
        RefreshOption(label: "1 分钟", seconds: 60),
        RefreshOption(label: "5 分钟", seconds: 300),
        RefreshOption(label: "15 分钟", seconds: 900),
        RefreshOption(label: "30 分钟", seconds: 1800),
    ]

    private enum Key {
        static let sound = "settings.soundEnabled"
        static let speech = "settings.speechEnabled"
        static let lines = "settings.customLines"
        static let reminder = "settings.lowBalanceReminderEnabled"
        static let threshold = "settings.lowBalanceThreshold"
        static let autoRefresh = "settings.autoRefreshEnabled"
        static let refreshSeconds = "settings.autoRefreshSeconds"
    }

    private let backend: SettingsBackend

    var soundEnabled: Bool { didSet { backend.set(soundEnabled, forKey: Key.sound) } }
    var speechEnabled: Bool { didSet { backend.set(speechEnabled, forKey: Key.speech) } }
    var customLinesText: String { didSet { backend.set(customLinesText, forKey: Key.lines) } }
    var lowBalanceReminderEnabled: Bool { didSet { backend.set(lowBalanceReminderEnabled, forKey: Key.reminder) } }
    var lowBalanceThresholdText: String { didSet { backend.set(lowBalanceThresholdText, forKey: Key.threshold) } }
    var autoRefreshEnabled: Bool { didSet { backend.set(autoRefreshEnabled, forKey: Key.autoRefresh) } }
    var autoRefreshSeconds: Int { didSet { backend.set(autoRefreshSeconds, forKey: Key.refreshSeconds) } }

    init(backend: SettingsBackend = UserDefaults.standard) {
        self.backend = backend
        self.soundEnabled = (backend.object(forKey: Key.sound) as? Bool) ?? true
        self.speechEnabled = (backend.object(forKey: Key.speech) as? Bool) ?? true
        self.customLinesText = (backend.object(forKey: Key.lines) as? String) ?? ""
        self.lowBalanceReminderEnabled = (backend.object(forKey: Key.reminder) as? Bool) ?? false
        self.lowBalanceThresholdText = (backend.object(forKey: Key.threshold) as? String) ?? "10.00"
        self.autoRefreshEnabled = (backend.object(forKey: Key.autoRefresh) as? Bool) ?? true
        self.autoRefreshSeconds = (backend.object(forKey: Key.refreshSeconds) as? Int) ?? 300
    }

    /// 自定义台词（每行一句）；留空用默认台词。
    var speechLines: [String] {
        let custom = customLinesText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return custom.isEmpty ? Self.defaultSpeechLines : custom
    }

    /// 提醒阈值；填了非法数字时为 nil。
    var lowBalanceThreshold: Double? {
        Double(lowBalanceThresholdText.trimmingCharacters(in: .whitespaces))
    }
}
