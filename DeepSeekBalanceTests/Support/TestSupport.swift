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

/// 内存版设置后端，代替 UserDefaults 做测试。
final class InMemorySettingsBackend: SettingsBackend {
    private var storage: [String: Any] = [:]

    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
}

/// 固定返回值的余额客户端。
struct MockBalanceClient: BalanceFetching {
    var result: Result<BalanceResponse, Error>

    func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        try result.get()
    }
}

/// 按顺序返回多个响应的余额客户端（用于模拟充值前后）。
final class SequencedBalanceClient: BalanceFetching {
    private var queue: [BalanceResponse]

    init(responses: [BalanceResponse]) {
        queue = responses
    }

    func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        guard !queue.isEmpty else {
            throw DeepSeekClientError.badResponse
        }
        return queue.removeFirst()
    }
}

/// 记录调用的小饭团音效/语音/通知 spy。
final class SpySounds: SoundPlaying {
    private(set) var played: [AppSound] = []
    func play(_ sound: AppSound) { played.append(sound) }
}

final class SpySpeech: SpeechSpeaking {
    private(set) var spoken: [String] = []
    func speak(_ text: String) { spoken.append(text) }
}

final class SpyNotifications: NotificationSending {
    var authorizationGranted = true
    private(set) var requestCount = 0
    private(set) var sent: [(current: String, threshold: String)] = []

    func requestAuthorization() async -> Bool {
        requestCount += 1
        return authorizationGranted
    }

    func sendLowBalanceNotification(current: String, threshold: String) async {
        sent.append((current, threshold))
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

    /// 指定总额的简单响应。
    static func balanceJSON(total: String) -> String {
        #"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"\#(total)","granted_balance":"0.00","topped_up_balance":"\#(total)"}]}"#
    }

    static func balance(from json: String) throws -> BalanceResponse {
        try JSONDecoder().decode(BalanceResponse.self, from: Data(json.utf8))
    }

    static func sampleResponse() throws -> BalanceResponse {
        try balance(from: sampleBalance)
    }
}

/// 构造一个全内存依赖的视图模型，保证测试确定性与隔离。
@MainActor
func makeViewModel(client: BalanceFetching,
                   store: APIKeyStoring = InMemoryAPIKeyStore(),
                   settings: SettingsStore? = nil,
                   monitor: BalanceMonitor? = nil,
                   sounds: SoundPlaying = SpySounds(),
                   speech: SpeechSpeaking = SpySpeech(),
                   notifications: NotificationSending = SpyNotifications()) -> BalanceViewModel {
    let resolvedSettings = settings ?? SettingsStore(backend: InMemorySettingsBackend())
    let resolvedMonitor = monitor ?? BalanceMonitor(backend: InMemorySettingsBackend())
    return BalanceViewModel(client: client,
                            store: store,
                            settings: resolvedSettings,
                            monitor: resolvedMonitor,
                            sounds: sounds,
                            speech: speech,
                            notifications: notifications)
}
