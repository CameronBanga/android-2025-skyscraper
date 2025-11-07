//
//  AccountManager.swift
//  Skyscraper
//
//  Multi-account management for BlueSky
//

import Foundation
import Combine

struct StoredAccount: Codable, Identifiable, Equatable {
    let id: String  // DID
    let handle: String
    let displayName: String?
    let avatar: String?

    static func == (lhs: StoredAccount, rhs: StoredAccount) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var accounts: [StoredAccount] = []
    @Published var activeAccountId: String?

    private let accountsKey = "skyscraper_accounts"
    private let activeAccountKey = "skyscraper_active_account"

    private init() {
        loadAccounts()
    }

    var activeAccount: StoredAccount? {
        guard let activeAccountId = activeAccountId else { return nil }
        return accounts.first { $0.id == activeAccountId }
    }

    func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([StoredAccount].self, from: data) {
            accounts = decoded
            print("📂 Loaded \(accounts.count) account(s) from UserDefaults")
            for account in accounts {
                print("  - @\(account.handle) (DID: \(account.id))")
            }
        } else {
            print("📂 No accounts found in UserDefaults")
        }

        activeAccountId = UserDefaults.standard.string(forKey: activeAccountKey)
        print("🔑 Active account ID: \(activeAccountId ?? "none")")

        // If no active account but we have accounts, set the first as active
        if activeAccountId == nil && !accounts.isEmpty {
            activeAccountId = accounts.first?.id
            saveActiveAccount()
            print("✅ Set first account as active: \(activeAccountId ?? "unknown")")
        }
    }

    func addAccount(did: String, handle: String, displayName: String?, avatar: String?) {
        // Check if account already exists
        if let existingIndex = accounts.firstIndex(where: { $0.id == did }) {
            // Update existing account
            accounts[existingIndex] = StoredAccount(
                id: did,
                handle: handle,
                displayName: displayName,
                avatar: avatar
            )
            print("🔄 Updated existing account: @\(handle)")
        } else {
            // Add new account
            let account = StoredAccount(
                id: did,
                handle: handle,
                displayName: displayName,
                avatar: avatar
            )
            accounts.append(account)
            print("➕ Added new account: @\(handle)")
        }

        saveAccounts()
        print("💾 Saved \(accounts.count) account(s) to UserDefaults")

        // Set as active account if it's the first one or if explicitly switching
        if accounts.count == 1 {
            activeAccountId = did
            saveActiveAccount()
            print("✅ Set as active account: @\(handle)")
        }
    }

    func switchAccount(to accountId: String) {
        guard accounts.contains(where: { $0.id == accountId }) else { return }
        activeAccountId = accountId
        saveActiveAccount()

        // Switch the session in ATProtoClient
        ATProtoClient.shared.switchToAccount(accountId: accountId)

        // Post notification that account switched
        NotificationCenter.default.post(name: .accountDidSwitch, object: nil)
        print("🔄 Switched active account to: \(accountId)")
    }

    func removeAccount(did: String) {
        accounts.removeAll { $0.id == did }
        saveAccounts()

        // If we removed the active account, switch to another or set to nil
        if activeAccountId == did {
            activeAccountId = accounts.first?.id
            saveActiveAccount()

            if activeAccountId == nil {
                // No accounts left, clear session
                KeychainService.shared.clearSession()
            } else {
                // Post notification that account switched
                NotificationCenter.default.post(name: .accountDidSwitch, object: nil)
            }
        }

        // Clear credentials for this account
        KeychainService.shared.clearCredentials(for: did)
    }

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }

    private func saveActiveAccount() {
        if let activeAccountId = activeAccountId {
            UserDefaults.standard.set(activeAccountId, forKey: activeAccountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeAccountKey)
        }
    }
}

extension NSNotification.Name {
    static let accountDidSwitch = NSNotification.Name("accountDidSwitch")
}
