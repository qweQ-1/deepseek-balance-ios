import Foundation
import Observation

/// 一次充值事件（用于掉落白饭）。
struct TopUpEvent: Equatable, Identifiable {
    let id: UUID
    let amount: Double
    let currency: String
}

/// 小饭团的说话气泡。
struct SpeechBubble: Equatable, Identifiable {
    let id: UUID
    let text: String
}

/// 喂饭后的 “+X” 闪光。
struct FedFlash: Equatable, Identifiable {
    let id: UUID
    let amount: Double
    let currency: String
}

/// 首页状态。
@MainActor
@Observable
final class BalanceViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(BalanceResponse)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastUpdated: Date?
    private(set) var hasStoredKey: Bool
    var apiKeyInput = ""

    // 小饭团
    private(set) var speechBubble: SpeechBubble?
    private(set) var lastTopUp: TopUpEvent?
    private(set) var fedFlash: FedFlash?

    // 提醒
    private(set) var isLowBalance = false
    private(set) var reminderNote: String?

    let settings: SettingsStore
    private let client: BalanceFetching
    private let store: APIKeyStoring
    private let monitor: BalanceMonitor
    private let sounds: SoundPlaying
    private let speech: SpeechSpeaking
    private let notifications: NotificationSending

    init(client: BalanceFetching = DeepSeekClient(),
         store: APIKeyStoring = KeychainAPIKeyStore(),
         settings: SettingsStore? = nil,
         monitor: BalanceMonitor = BalanceMonitor(),
         sounds: SoundPlaying = SystemSoundPlayer(),
         speech: SpeechSpeaking = SystemSpeechSpeaker(),
         notifications: NotificationSending = SystemNotificationSender()) {
        self.client = client
        self.store = store
        self.settings = settings ?? SettingsStore()
        self.monitor = monitor
        self.sounds = sounds
        self.speech = speech
        self.notifications = notifications
        self.hasStoredKey = !(store.loadKey() ?? "").isEmpty
    }

    // MARK: - 查询

    /// 冷启动：已保存 Key 且还没查过时自动查一次。
    func refreshIfNeeded() async {
        if hasStoredKey, case .idle = state {
            await refresh()
        }
    }

    /// 回到前台时刷新一次（避免重复刷新时跳过）。
    func refreshOnForeground() async {
        guard hasStoredKey, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        guard let key = store.loadKey(), !key.isEmpty else {
            hasStoredKey = false
            state = .failed("还没有设置 API Key")
            return
        }
        state = .loading
        do {
            let response = try await client.fetchBalance(apiKey: key)
            state = .loaded(response)
            lastUpdated = Date()
            await processMonitor(response)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

    /// 定时刷新循环：App 在前台时按设置的间隔刷新。
    func autoRefreshLoop() async {
        while !Task.isCancelled {
            let seconds = UInt64(max(30, settings.autoRefreshSeconds)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: seconds)
            if Task.isCancelled { return }
            guard settings.autoRefreshEnabled, hasStoredKey, !isLoading else { continue }
            await refresh()
        }
    }

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// 充值检测 + 余额不足提醒（每次查询成功后调用）。
    private func processMonitor(_ response: BalanceResponse) async {
        guard let info = response.balanceInfos.first,
              let total = Double(info.totalBalance) else { return }

        if let delta = TopUpDetector.topUpAmount(previous: monitor.lastKnownTotal, current: total) {
            lastTopUp = TopUpEvent(id: UUID(), amount: delta, currency: info.currency)
            if settings.soundEnabled { sounds.play(.ding) }
        }
        monitor.lastKnownTotal = total

        guard settings.lowBalanceReminderEnabled, let threshold = settings.lowBalanceThreshold else {
            isLowBalance = false
            return
        }
        let low = total < threshold
        isLowBalance = low
        if low, !monitor.wasLow {
            monitor.wasLow = true
            let granted = await notifications.requestAuthorization()
            if granted {
                await notifications.sendLowBalanceNotification(
                    current: CurrencyFormat.display(amount: String(format: "%.2f", total), currency: info.currency),
                    threshold: "¥" + settings.lowBalanceThresholdText.trimmingCharacters(in: .whitespaces)
                )
            }
        } else if !low, monitor.wasLow {
            monitor.wasLow = false
        }
    }

    // MARK: - 小饭团

    /// 点小饭团：音效 + 说一句台词（台词可在设置里自定义）。
    func mascotTapped() {
        if settings.soundEnabled { sounds.play(.pop) }
        let line = settings.speechLines.randomElement() ?? "……"
        speak(line)
    }

    /// 把白饭喂给小饭团：吧唧音效 + 说话 + “+X” 闪光。
    func feedRice(amount: Double, currency: String) {
        lastTopUp = nil
        if settings.soundEnabled { sounds.play(.eat) }
        speak("吧唧吧唧，饭饭好好吃！")
        let flash = FedFlash(id: UUID(), amount: amount, currency: currency)
        fedFlash = flash
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard let self, self.fedFlash?.id == flash.id else { return }
            self.fedFlash = nil
        }
    }

    private func speak(_ line: String) {
        if settings.speechEnabled { speech.speak(line) }
        let bubble = SpeechBubble(id: UUID(), text: line)
        speechBubble = bubble
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard let self, self.speechBubble?.id == bubble.id else { return }
            self.speechBubble = nil
        }
    }

    // MARK: - Key 管理

    /// 保存输入框里的 Key（去掉首尾空白）并立即查询。
    func saveKeyAndRefresh() async {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try store.saveKey(key)
        } catch {
            state = .failed("保存 API Key 失败：\(error.localizedDescription)")
            return
        }
        hasStoredKey = true
        apiKeyInput = ""
        await refresh()
    }

    func clearKey() {
        store.deleteKey()
        hasStoredKey = false
        state = .idle
        lastUpdated = nil
        lastTopUp = nil
        fedFlash = nil
        speechBubble = nil
        isLowBalance = false
        monitor.reset()
    }

    /// 开关余额提醒；打开时请求通知权限。
    func reminderToggled(_ enabled: Bool) async {
        settings.lowBalanceReminderEnabled = enabled
        if enabled {
            let granted = await notifications.requestAuthorization()
            reminderNote = granted ? nil : "未获得通知权限，提醒将只显示在应用内"
        } else {
            reminderNote = nil
            isLowBalance = false
        }
    }
}
