import Foundation
import Security

enum KeychainStore {
    private static let service = "co.skyones.releasepilot"
    private static let account = "github-token"

    static func readToken() -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return "" }
        return token
    }

    static func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let attributes: [CFString: Any] = [kSecValueData: data]
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw ReleasePilotError.keychain
            }
        } else if status != errSecSuccess {
            throw ReleasePilotError.keychain
        }
    }
}
