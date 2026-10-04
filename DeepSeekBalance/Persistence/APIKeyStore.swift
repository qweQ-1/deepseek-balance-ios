import Foundation
import Security

/// 保存/读取 API Key 的抽象，方便测试替换。
protocol APIKeyStoring {
    func loadKey() -> String?
    func saveKey(_ key: String) throws
    func deleteKey()
}

enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

/// API Key 只保存在本机 Keychain（kSecClassGenericPassword），不会同步到别处。
struct KeychainAPIKeyStore: APIKeyStoring {
    var service = "com.qweq-1.deepseekbalance"
    var account = "deepseek-api-key"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func loadKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func saveKey(_ key: String) throws {
        let data = Data(key.utf8)

        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainError.unexpectedStatus(updateStatus)
    }

    func deleteKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
