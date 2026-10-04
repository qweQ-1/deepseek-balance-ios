import Foundation
import Testing
@testable import DeepSeekBalance

@Suite struct BalanceDecodingTests {
    @Test func decodesStringAmounts() throws {
        let response = try TestJSON.balance(from: TestJSON.sampleBalance)
        #expect(response.isAvailable)
        let info = try #require(response.balanceInfos.first)
        #expect(info.currency == "CNY")
        #expect(info.totalBalance == "46.29")
        #expect(info.grantedBalance == "6.29")
        #expect(info.toppedUpBalance == "40.00")
    }

    @Test func decodesNumericAmounts() throws {
        let json = #"{"is_available":false,"balance_infos":[{"currency":"USD","total_balance":12.5,"granted_balance":0,"topped_up_balance":12.5}]}"#
        let response = try TestJSON.balance(from: json)
        #expect(response.isAvailable == false)
        let info = try #require(response.balanceInfos.first)
        #expect(info.currency == "USD")
        #expect(info.totalBalance == "12.50")
        #expect(info.grantedBalance == "0.00")
        #expect(info.toppedUpBalance == "12.50")
    }

    @Test func toleratesMissingOptionalAmounts() throws {
        let json = #"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"1.00"}]}"#
        let response = try TestJSON.balance(from: json)
        let info = try #require(response.balanceInfos.first)
        #expect(info.grantedBalance == nil)
        #expect(info.toppedUpBalance == nil)
        #expect(info.grantedBalanceText == "—")
        #expect(info.toppedUpBalanceText == "—")
    }

    @Test(arguments: zip(["CNY", "USD", "HKD", "cny"], ["¥", "$", "", "¥"]))
    func currencySymbols(currency: String, expectedSymbol: String) {
        #expect(CurrencyFormat.symbol(for: currency) == expectedSymbol)
    }

    @Test func formatsDisplayAmounts() {
        #expect(CurrencyFormat.display(amount: "40.00", currency: "CNY") == "¥40.00")
        #expect(CurrencyFormat.display(amount: "12.50", currency: "USD") == "$12.50")
        #expect(CurrencyFormat.display(amount: "9.90", currency: "HKD") == "9.90 HKD")
    }
}
