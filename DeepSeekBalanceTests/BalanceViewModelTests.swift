import Foundation
import Testing
@testable import DeepSeekBalance

@MainActor
@Suite struct BalanceViewModelTests {
    @Test func refreshWithoutStoredKeyFails() async {
        let model = BalanceViewModel(
            client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
            store: InMemoryAPIKeyStore()
        )
        await model.refresh()
        #expect(model.state == .failed("还没有设置 API Key"))
    }

    @Test func refreshLoadsBalance() async throws {
        let response = try TestJSON.sampleResponse()
        let model = BalanceViewModel(
            client: MockBalanceClient(result: .success(response)),
            store: InMemoryAPIKeyStore(key: "sk-test")
        )
        await model.refresh()
        #expect(model.state == .loaded(response))
        #expect(model.lastUpdated != nil)
    }

    @Test func refreshFailureShowsMessage() async {
        let model = BalanceViewModel(
            client: MockBalanceClient(result: .failure(
                DeepSeekClientError.unauthorized(message: "Authentication Fails")
            )),
            store: InMemoryAPIKeyStore(key: "sk-bad")
        )
        await model.refresh()
        #expect(model.state == .failed("认证失败：Authentication Fails"))
    }

    @Test func saveKeyStoresAndRefreshes() async throws {
        let response = try TestJSON.sampleResponse()
        let store = InMemoryAPIKeyStore()
        let model = BalanceViewModel(
            client: MockBalanceClient(result: .success(response)),
            store: store
        )
        model.apiKeyInput = "  sk-new  "
        await model.saveKeyAndRefresh()
        #expect(store.stored == "sk-new")
        #expect(model.hasStoredKey)
        #expect(model.apiKeyInput.isEmpty)
        #expect(model.state == .loaded(response))
    }

    @Test func clearKeyResetsState() async {
        let model = BalanceViewModel(
            client: MockBalanceClient(result: .failure(DeepSeekClientError.missingKey)),
            store: InMemoryAPIKeyStore(key: "sk-x")
        )
        await model.refresh()
        model.clearKey()
        #expect(model.hasStoredKey == false)
        #expect(model.state == .idle)
        #expect(model.lastUpdated == nil)
    }
}
