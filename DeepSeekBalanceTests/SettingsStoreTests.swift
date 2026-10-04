import Foundation
import Testing
@testable import DeepSeekBalance

@MainActor
@Suite struct SettingsStoreTests {
    @Test func defaults() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        #expect(store.soundEnabled)
        #expect(store.speechEnabled)
        #expect(store.customLinesText.isEmpty)
        #expect(store.lowBalanceReminderEnabled == false)
        #expect(store.lowBalanceThresholdText == "10.00")
        #expect(store.autoRefreshEnabled)
        #expect(store.autoRefreshSeconds == 300)
        #expect(store.speechLines == SettingsStore.defaultSpeechLines)
    }

    @Test func persistsAcrossInstances() {
        let backend = InMemorySettingsBackend()
        let first = SettingsStore(backend: backend)
        first.soundEnabled = false
        first.speechEnabled = false
        first.customLinesText = "你好\n世界"
        first.lowBalanceReminderEnabled = true
        first.lowBalanceThresholdText = "25.5"
        first.autoRefreshEnabled = false
        first.autoRefreshSeconds = 60

        let second = SettingsStore(backend: backend)
        #expect(second.soundEnabled == false)
        #expect(second.speechEnabled == false)
        #expect(second.lowBalanceReminderEnabled)
        #expect(second.lowBalanceThresholdText == "25.5")
        #expect(second.autoRefreshEnabled == false)
        #expect(second.autoRefreshSeconds == 60)
        #expect(second.speechLines == ["你好", "世界"])
    }

    @Test func customLinesParsing() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        store.customLinesText = " 甲 \n\n 乙 \n   "
        #expect(store.speechLines == ["甲", "乙"])

        store.customLinesText = "   \n  "
        #expect(store.speechLines == SettingsStore.defaultSpeechLines)
    }

    @Test func thresholdParsing() {
        let store = SettingsStore(backend: InMemorySettingsBackend())
        store.lowBalanceThresholdText = "abc"
        #expect(store.lowBalanceThreshold == nil)

        store.lowBalanceThresholdText = " 12.5 "
        #expect(store.lowBalanceThreshold == 12.5)
    }
}
