import Foundation
import Testing
@testable import DeepSeekBalance

@Suite struct TopUpLogicTests {
    @Test func detectsIncrease() {
        let delta = TopUpDetector.topUpAmount(previous: 46.29, current: 86.29)
        #expect(delta != nil)
        #expect(abs((delta ?? 0) - 40) < 0.001)
    }

    @Test func ignoresFirstObservation() {
        #expect(TopUpDetector.topUpAmount(previous: nil, current: 100) == nil)
    }

    @Test func ignoresDecrease() {
        #expect(TopUpDetector.topUpAmount(previous: 100, current: 90) == nil)
    }

    @Test func ignoresTinyChange() {
        #expect(TopUpDetector.topUpAmount(previous: 100, current: 100.001) == nil)
    }

    @Test func riceBowlsPerYuan() {
        #expect(RiceRain.bowls(for: 40.0) == 40)
        #expect(RiceRain.bowls(for: 0.5) == 1)
        #expect(RiceRain.bowls(for: 999) == 60)
        #expect(RiceRain.bowls(for: 0) == 0)
        #expect(RiceRain.bowls(for: 40.0, cap: 10) == 10)
    }

    @Test func monitorRoundTrip() {
        let backend = InMemorySettingsBackend()
        let monitor = BalanceMonitor(backend: backend)
        #expect(monitor.lastKnownTotal == nil)
        #expect(monitor.wasLow == false)

        monitor.lastKnownTotal = 42.5
        monitor.wasLow = true

        let reloaded = BalanceMonitor(backend: backend)
        #expect(reloaded.lastKnownTotal == 42.5)
        #expect(reloaded.wasLow)

        reloaded.reset()
        #expect(BalanceMonitor(backend: backend).lastKnownTotal == nil)
        #expect(BalanceMonitor(backend: backend).wasLow == false)
    }
}
