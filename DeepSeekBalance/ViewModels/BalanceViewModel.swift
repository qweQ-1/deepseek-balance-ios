import Foundation
import Observation

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

    private let client: BalanceFetching
    private let store: APIKeyStoring

    init(client: BalanceFetching = DeepSeekClient(), store: APIKeyStoring = KeychainAPIKeyStore()) {
        self.client = client
        self.store = store
        self.hasStoredKey = !(store.loadKey() ?? "").isEmpty
    }

    /// 冷启动：已保存 Key 且还没查过时自动查一次。
    func refreshIfNeeded() async {
        if hasStoredKey, case .idle = state {
            await refresh()
        }
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
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

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
    }
}
