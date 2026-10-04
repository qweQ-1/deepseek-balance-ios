import Foundation
import Testing
@testable import DeepSeekBalance

@MainActor
@Suite struct BalanceViewModelTests {
    // MARK: - 基础查询

    @Test func refreshWithoutStoredKeyFails() async {
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)))
        await model.refresh()
        #expect(model.state == .failed("还没有设置 API Key"))
    }

    @Test func refreshLoadsBalance() async throws {
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"))
        await model.refresh()
        #expect(model.state == .loaded(response))
        #expect(model.lastUpdated != nil)
        #expect(model.lastTopUp == nil)
        #expect(model.isLowBalance == false)
    }

    @Test func refreshFailureShowsMessage() async {
        let model = makeViewModel(
            client: MockBalanceClient(result: .failure(DeepSeekClientError.unauthorized(message: "Authentication Fails"))),
            store: InMemoryAPIKeyStore(key: "sk-bad"))
        await model.refresh()
        #expect(model.state == .failed("认证失败：Authentication Fails"))
    }

    // MARK: - 充值检测（掉饭）

    @Test func detectsTopUpOnIncrease() async throws {
        let sounds = SpySounds()
        let first = try TestJSON.balance(from: TestJSON.balanceJSON(total: "46.29"))
        let second = try TestJSON.balance(from: TestJSON.balanceJSON(total: "86.29"))
        let model = makeViewModel(client: SequencedBalanceClient(responses: [first, second]),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  sounds: sounds)

        await model.refresh()
        #expect(model.lastTopUp == nil)

        await model.refresh()
        let topup = try #require(model.lastTopUp)
        #expect(abs(topup.amount - 40) < 0.001)
        #expect(topup.currency == "CNY")
        #expect(sounds.played.contains(.ding))
    }

    @Test func noTopUpWhenBalanceDecreases() async throws {
        let first = try TestJSON.balance(from: TestJSON.balanceJSON(total: "86.29"))
        let second = try TestJSON.balance(from: TestJSON.balanceJSON(total: "46.29"))
        let model = makeViewModel(client: SequencedBalanceClient(responses: [first, second]),
                                  store: InMemoryAPIKeyStore(key: "sk-test"))
        await model.refresh()
        await model.refresh()
        #expect(model.lastTopUp == nil)
    }

    @Test func feedRiceShowsFlashAndPlaysEat() async throws {
        let sounds = SpySounds()
        let speech = SpySpeech()
        let first = try TestJSON.balance(from: TestJSON.balanceJSON(total: "46.29"))
        let second = try TestJSON.balance(from: TestJSON.balanceJSON(total: "86.29"))
        let model = makeViewModel(client: SequencedBalanceClient(responses: [first, second]),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  sounds: sounds,
                                  speech: speech)
        await model.refresh()
        await model.refresh()
        let topup = try #require(model.lastTopUp)

        model.feedRice(amount: topup.amount, currency: topup.currency)

        #expect(model.lastTopUp == nil)
        #expect(model.fedFlash?.amount == topup.amount)
        #expect(sounds.played.last == .eat)
        #expect(speech.spoken.contains { $0.contains("饭饭") })
    }

    // MARK: - 小饭团

    @Test func mascotTapUsesCustomLine() {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.customLinesText = "测试台词"
        let sounds = SpySounds()
        let speech = SpySpeech()
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
                                  settings: settings,
                                  sounds: sounds,
                                  speech: speech)
        model.mascotTapped()
        #expect(model.speechBubble?.text == "测试台词")
        #expect(sounds.played == [.pop])
        #expect(speech.spoken == ["测试台词"])
    }

    @Test func mascotTapRespectsToggles() {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.soundEnabled = false
        settings.speechEnabled = false
        let sounds = SpySounds()
        let speech = SpySpeech()
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
                                  settings: settings,
                                  sounds: sounds,
                                  speech: speech)
        model.mascotTapped()
        #expect(sounds.played.isEmpty)
        #expect(speech.spoken.isEmpty)
        #expect(model.speechBubble != nil)
    }

    // MARK: - 余额提醒

    @Test func lowBalanceReminderFiresOncePerCrossing() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.lowBalanceReminderEnabled = true
        settings.lowBalanceThresholdText = "50"
        let notifications = SpyNotifications()
        let low = try TestJSON.balance(from: TestJSON.balanceJSON(total: "30"))
        let high = try TestJSON.balance(from: TestJSON.balanceJSON(total: "80"))
        let model = makeViewModel(client: SequencedBalanceClient(responses: [low, low, high, low]),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  notifications: notifications)

        await model.refresh()
        #expect(notifications.sent.count == 1)
        #expect(model.isLowBalance)

        await model.refresh()
        #expect(notifications.sent.count == 1)

        await model.refresh()
        #expect(model.isLowBalance == false)

        await model.refresh()
        #expect(notifications.sent.count == 2)
    }

    @Test func reminderDisabledMeansNoNotification() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.lowBalanceThresholdText = "50"
        let notifications = SpyNotifications()
        let low = try TestJSON.balance(from: TestJSON.balanceJSON(total: "30"))
        let model = makeViewModel(client: MockBalanceClient(result: .success(low)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  notifications: notifications)
        await model.refresh()
        #expect(notifications.sent.isEmpty)
        #expect(model.isLowBalance == false)
    }

    @Test func reminderToggleRequestsAuthorization() async {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        let notifications = SpyNotifications()
        notifications.authorizationGranted = false
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
                                  settings: settings,
                                  notifications: notifications)

        await model.reminderToggled(true)
        #expect(settings.lowBalanceReminderEnabled)
        #expect(model.reminderNote != nil)

        notifications.authorizationGranted = true
        await model.reminderToggled(true)
        #expect(model.reminderNote == nil)

        await model.reminderToggled(false)
        #expect(settings.lowBalanceReminderEnabled == false)
    }

    // MARK: - 画中画余额窗

    @Test func pipStartsOnBackgroundWhenEnabled() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.pipEnabled = true
        let pip = SpyPiP()
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  pip: pip)
        await model.refresh()
        model.handleScenePhase(active: false)
        #expect(pip.lastStartedText == "¥46.29")

        model.handleScenePhase(active: true)
        #expect(pip.stopCount == 1)
    }

    @Test func pipStaysOffWhenDisabled() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        let pip = SpyPiP()
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  pip: pip)
        await model.refresh()
        model.handleScenePhase(active: false)
        #expect(pip.lastStartedText == nil)
    }

    @Test func pipUpdatesAfterRefresh() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.pipEnabled = true
        let pip = SpyPiP()
        let first = try TestJSON.balance(from: TestJSON.balanceJSON(total: "46.29"))
        let second = try TestJSON.balance(from: TestJSON.balanceJSON(total: "86.29"))
        let model = makeViewModel(client: SequencedBalanceClient(responses: [first, second]),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  pip: pip)
        await model.refresh()
        model.handleScenePhase(active: false)
        await model.refresh()
        #expect(pip.updates.contains("¥86.29"))
    }

    @Test func pipToggledOffStops() {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        let pip = SpyPiP()
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
                                  settings: settings,
                                  pip: pip)
        model.pipToggled(true)
        #expect(settings.pipEnabled)
        model.pipToggled(false)
        #expect(settings.pipEnabled == false)
        #expect(pip.stopCount >= 1)
    }

    @Test func pipPreviewStartsEvenWithoutBalance() {
        let pip = SpyPiP()
        let model = makeViewModel(client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
                                  pip: pip)
        model.pipPreviewStart()
        #expect(pip.lastStartedText == "DeepSeek 余额")
        model.pipPreviewStop()
        #expect(pip.stopCount >= 1)
    }

    // MARK: - 保持后台运行

    @Test func keepAliveFollowsSceneWhenEnabled() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.backgroundKeepAliveEnabled = true
        let keeper = SpyKeeper()
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  keeper: keeper)
        model.handleScenePhase(active: false)
        #expect(keeper.isOn)
        model.handleScenePhase(active: true)
        #expect(keeper.isOn == false)
    }

    @Test func keepAliveOffByDefault() async throws {
        let keeper = SpyKeeper()
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  keeper: keeper)
        model.handleScenePhase(active: false)
        #expect(keeper.isOn == false)
    }

    @Test func keepAliveToggleOffReleases() async throws {
        let settings = SettingsStore(backend: InMemorySettingsBackend())
        settings.backgroundKeepAliveEnabled = true
        let keeper = SpyKeeper()
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-test"),
                                  settings: settings,
                                  keeper: keeper)
        model.handleScenePhase(active: false)
        #expect(keeper.isOn)
        model.backgroundKeepAliveToggled(false)
        #expect(settings.backgroundKeepAliveEnabled == false)
        #expect(keeper.isOn == false)
    }

    // MARK: - Key 管理

    @Test func saveKeyStoresAndRefreshes() async throws {
        let response = try TestJSON.sampleResponse()
        let store = InMemoryAPIKeyStore()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)), store: store)
        model.apiKeyInput = "  sk-new  "
        await model.saveKeyAndRefresh()
        #expect(store.stored == "sk-new")
        #expect(model.hasStoredKey)
        #expect(model.apiKeyInput.isEmpty)
        #expect(model.state == .loaded(response))
    }

    @Test func clearKeyResetsStateAndMonitor() async throws {
        let monitorBackend = InMemorySettingsBackend()
        let monitor = BalanceMonitor(backend: monitorBackend)
        let response = try TestJSON.sampleResponse()
        let model = makeViewModel(client: MockBalanceClient(result: .success(response)),
                                  store: InMemoryAPIKeyStore(key: "sk-x"),
                                  monitor: monitor)
        await model.refresh()
        #expect(monitor.lastKnownTotal != nil)

        model.clearKey()
        #expect(model.hasStoredKey == false)
        #expect(model.state == .idle)
        #expect(model.lastUpdated == nil)
        #expect(model.lastTopUp == nil)
        #expect(monitor.lastKnownTotal == nil)
    }
}
