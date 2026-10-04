import Foundation

/// 查询 DeepSeek 余额可能出现的错误。
enum DeepSeekClientError: Error, Equatable {
    case missingKey
    case unauthorized(message: String)
    case http(status: Int, message: String)
    case badResponse
    case network(message: String)
}

extension DeepSeekClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "还没有设置 API Key"
        case .unauthorized(let message):
            return "认证失败：\(message)"
        case .http(let status, let message):
            return "查询失败（HTTP \(status)）：\(message)"
        case .badResponse:
            return "接口返回了无法解析的数据"
        case .network(let message):
            return "网络请求失败：\(message)"
        }
    }
}

/// 拉取余额的抽象，方便测试替换。
protocol BalanceFetching {
    func fetchBalance(apiKey: String) async throws -> BalanceResponse
}

/// DeepSeek 官方余额接口客户端。
struct DeepSeekClient: BalanceFetching {
    static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    var session: URLSession = .shared
    var timeout: TimeInterval = 20

    func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw DeepSeekClientError.missingKey }

        var request = URLRequest(url: Self.balanceURL)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekClientError.network(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekClientError.badResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = Self.serverMessage(from: data) ?? "未知错误"
            if http.statusCode == 401 || http.statusCode == 403 {
                throw DeepSeekClientError.unauthorized(message: message)
            }
            throw DeepSeekClientError.http(status: http.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(BalanceResponse.self, from: data)
        } catch {
            throw DeepSeekClientError.badResponse
        }
    }

    /// 从错误响应里取服务端消息（兼容 JSON 和纯文本）。
    private static func serverMessage(from data: Data) -> String? {
        struct APIErrorEnvelope: Decodable {
            struct APIError: Decodable {
                let message: String?
            }
            let error: APIError?
        }
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
           let message = envelope.error?.message,
           !message.isEmpty {
            return message
        }
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty, text.count <= 300, !text.hasPrefix("{") {
            return text
        }
        return nil
    }
}
