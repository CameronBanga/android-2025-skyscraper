//
//  KeychainManager.swift
//  Skyscraper
//
//  Secure keychain storage for credentials and session
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case unknown(OSStatus)
    case itemNotFound
    case invalidData
}

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.skyscraper.app"

    private init() {}

    // MARK: - Save

    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: key, data: data)
    }

    // MARK: - Retrieve

    func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func retrieveString(key: String) throws -> String {
        let data = try retrieve(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Delete

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Convenience Methods

    func saveSession(_ session: ATProtoSession, for accountId: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        try save(key: "atproto_session_\(accountId)", data: data)
    }

    func retrieveSession(for accountId: String) -> ATProtoSession? {
        guard let data = try? retrieve(key: "atproto_session_\(accountId)") else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(ATProtoSession.self, from: data)
    }

    func deleteSession(for accountId: String) {
        try? delete(key: "atproto_session_\(accountId)")
    }

    func saveCredentials(identifier: String, password: String, for accountId: String) throws {
        try save(key: "user_identifier_\(accountId)", value: identifier)
        try save(key: "user_password_\(accountId)", value: password)
    }

    func retrieveCredentials(for accountId: String) -> (identifier: String, password: String)? {
        guard let identifier = try? retrieveString(key: "user_identifier_\(accountId)"),
              let password = try? retrieveString(key: "user_password_\(accountId)") else {
            return nil
        }
        return (identifier, password)
    }

    func deleteCredentials(for accountId: String) {
        try? delete(key: "user_identifier_\(accountId)")
        try? delete(key: "user_password_\(accountId)")
    }
}

// MARK: - KeychainService (Convenience wrapper using AccountManager)
@MainActor
class KeychainService {
    static let shared = KeychainService()

    private let keychain = KeychainManager.shared
    private var accountManager: AccountManager { AccountManager.shared }

    private init() {}

    var currentAccountId: String? {
        accountManager.activeAccountId
    }

    func saveSession(_ session: ATProtoSession) throws {
        let accountId = session.did
        try keychain.saveSession(session, for: accountId)
    }

    func retrieveSession() -> ATProtoSession? {
        guard let accountId = currentAccountId else { return nil }
        return keychain.retrieveSession(for: accountId)
    }

    func clearSession() {
        guard let accountId = currentAccountId else { return }
        keychain.deleteSession(for: accountId)
    }

    func saveCredentials(identifier: String, password: String, for accountId: String) throws {
        try keychain.saveCredentials(identifier: identifier, password: password, for: accountId)
    }

    func retrieveCredentials() -> (identifier: String, password: String)? {
        guard let accountId = currentAccountId else { return nil }
        return keychain.retrieveCredentials(for: accountId)
    }

    func clearCredentials(for accountId: String) {
        keychain.deleteCredentials(for: accountId)
        keychain.deleteSession(for: accountId)
    }
}
