import Foundation
import Testing
@testable import DeepSeekBalance

@Suite(.serialized)
struct DeepSeekClientTests {
    private func makeClient() -> DeepSeekClient {
        var client = DeepSeekClient()
        client.session = MockURLProtocol.makeSession()
        return client
    }

    @Test func sendsBearerTokenAndParsesBalance() async throws {
        var capturedAuthorization: String?
        MockURLProtocol.handler = { request in
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return MockURLProtocol.json(status: 200, body: TestJSON.sampleBalance)
        }

        let response = try await makeClient().fetchBalance(apiKey: "sk-test-123")

        #expect(capturedAuthorization == "Bearer sk-test-123")
        #expect(response.isAvailable)
        let info = try #require(response.balanceInfos.first)
        #expect(info.currency == "CNY")
        #expect(info.totalBalance == "46.29")
    }

    @Test func rejectsEmptyKeyWithoutNetworkCall() async {
        MockURLProtocol.handler = { _ in
            Issue.record("空白 Key 不应该发起网络请求")
            return MockURLProtocol.json(status: 500, body: "{}")
        }

        do {
            _ = try await makeClient().fetchBalance(apiKey: "   ")
            Issue.record("空白 Key 应该抛出 missingKey")
        } catch let error as DeepSeekClientError {
            #expect(error == .missingKey)
        } catch {
            Issue.record("错误类型不对：\(error)")
        }
    }

    @Test func maps401ToUnauthorized() async {
        MockURLProtocol.handler = { _ in
            MockURLProtocol.json(status: 401, body: #"{"error":{"message":"Authentication Fails"}}"#)
        }

        do {
            _ = try await makeClient().fetchBalance(apiKey: "sk-bad")
            Issue.record("401 应该抛出 unauthorized")
        } catch let error as DeepSeekClientError {
            #expect(error == .unauthorized(message: "Authentication Fails"))
        } catch {
            Issue.record("错误类型不对：\(error)")
        }
    }

    @Test func maps500ToHTTPError() async {
        MockURLProtocol.handler = { _ in
            MockURLProtocol.json(status: 500, body: #"{"error":{"message":"Internal Error"}}"#)
        }

        do {
            _ = try await makeClient().fetchBalance(apiKey: "sk-x")
            Issue.record("500 应该抛出 http 错误")
        } catch let error as DeepSeekClientError {
            #expect(error == .http(status: 500, message: "Internal Error"))
        } catch {
            Issue.record("错误类型不对：\(error)")
        }
    }

    @Test func mapsTransportFailureToNetworkError() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await makeClient().fetchBalance(apiKey: "sk-x")
            Issue.record("传输失败应该抛出 network 错误")
        } catch let error as DeepSeekClientError {
            guard case .network = error else {
                Issue.record("预期 network，实际 \(error)")
                return
            }
        } catch {
            Issue.record("错误类型不对：\(error)")
        }
    }
}
