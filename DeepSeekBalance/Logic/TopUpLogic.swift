import Foundation

/// 充值（余额增加）检测。
enum TopUpDetector {
    /// 返回本次检测到的充值金额；首次查询、余额未增或增幅过小返回 nil。
    static func topUpAmount(previous: Double?, current: Double, minimumDelta: Double = 0.005) -> Double? {
        guard let previous, current > previous + minimumDelta else { return nil }
        return current - previous
    }
}

/// 掉饭规则：每充值 1 元掉一碗饭，最多 60 碗。
enum RiceRain {
    static let bowlValue: Double = 1.0

    static func bowls(for amount: Double, cap: Int = 60) -> Int {
        guard amount >= 0.005 else { return 0 }
        return max(1, min(cap, Int(amount.rounded(.down))))
    }
}

/// 跨启动保存的余额监控状态（用于充值检测与提醒去重）。
final class BalanceMonitor {
    private enum Key {
        static let lastTotal = "monitor.lastTotal"
        static let wasLow = "monitor.wasLow"
    }

    private let backend: SettingsBackend

    init(backend: SettingsBackend = UserDefaults.standard) {
        self.backend = backend
    }

    var lastKnownTotal: Double? {
        get { backend.object(forKey: Key.lastTotal) as? Double }
        set { backend.set(newValue, forKey: Key.lastTotal) }
    }

    /// 上一次检查时是否已处于“低于阈值”状态（防止重复提醒）。
    var wasLow: Bool {
        get { (backend.object(forKey: Key.wasLow) as? Bool) ?? false }
        set { backend.set(newValue, forKey: Key.wasLow) }
    }

    func reset() {
        lastKnownTotal = nil
        wasLow = false
    }
}
