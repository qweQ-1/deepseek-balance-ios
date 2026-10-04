import Foundation
@testable import DeepSeekBalance

/// 内存版 Key 存储，代替 Keychain 做测试。
final class InMemoryAPIKeyStore: APIKeyStoring {
    private(set) var stored: String?

    init(key: String? = nil) {
        stored = key
    }

    func loadKey() -> String? { stored }
    func saveKey(_ key: String) throws { stored = key }
    func deleteKey() { stored = nil }
}

/// 固定返回值的余额客户端，代替真实网络请求。
struct MockBalanceClient: BalanceFetching {
    var result: Result<BalanceResponse, Error>

    func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        try result.get()
    }
}

/// 测试用 JSON 与解码助手。
enum TestJSON {
    static let sampleBalance = #"""
    {
      "is_available": true,
      "balance_infos": [
        {
          "currency": "CNY",
          "total_balance": "46.29",
          "granted_balance": "6.29",
          "topped_up_balance": "40.00"
        }
      ]
    }
    """#

    static func balance(from json: String) throws -> BalanceResponse {
        try JSONDecoder().decode(BalanceResponse.self, from: Data(json.utf8))
    }

    static func sampleResponse() throws -> BalanceResponse {
        try balance(from: sampleBalance)
    }
}
