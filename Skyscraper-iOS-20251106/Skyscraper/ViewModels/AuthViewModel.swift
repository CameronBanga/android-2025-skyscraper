//
//  AuthViewModel.swift
//  Skyscraper
//
//  Handles authentication state and login flow
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingSession = true  // Start as true while checking for saved session
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = ATProtoClient.shared
    private let accountManager = AccountManager.shared

    init() {
        // Don't set isAuthenticated immediately - wait for session to load
        print("🔄 AuthViewModel init - waiting for session to load...")

        // Ensure that if we have a session, the account exists in AccountManager
        Task { @MainActor in
            // Give ATProtoClient time to load the session from keychain
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Now check if authenticated after session has had time to load
            isAuthenticated = client.isAuthenticated
            isCheckingSession = false
            print("✅ AuthViewModel session loaded - isAuthenticated: \(isAuthenticated)")

            await syncCurrentSessionWithAccountManager()
        }
    }

    private func syncCurrentSessionWithAccountManager() async {
        // If we have a session but no accounts, we need to populate AccountManager
        print("🔍 Syncing session with AccountManager...")
        print("   Current session: \(client.session?.handle ?? "nil")")
        print("   Current accounts: \(accountManager.accounts.count)")

        guard let session = client.session else {
            print("❌ No session to sync")
            return
        }

        // Check if this account already exists in AccountManager
        let accountExists = accountManager.accounts.contains { $0.id == session.did }

        if !accountExists {
            // Fetch profile and add to AccountManager
            do {
                let profile = try await client.getProfile(actor: session.did)
                accountManager.addAccount(
                    did: session.did,
                    handle: profile.handle,
                    displayName: profile.displayName,
                    avatar: profile.avatar
                )
                print("✅ Synced existing session with AccountManager: \(profile.handle)")
            } catch {
                // If profile fetch fails, still add account with basic info
                accountManager.addAccount(
                    did: session.did,
                    handle: session.handle,
                    displayName: nil,
                    avatar: nil
                )
                print("✅ Synced existing session with AccountManager (basic info): \(session.handle)")
            }
        }
    }

    func login(identifier: String, password: String, rememberMe: Bool = false, customPDSURL: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        print("🔐 Login attempt with identifier: \(identifier)")
        if let pdsURL = customPDSURL {
            print("🔧 Using custom PDS URL: \(pdsURL)")
        }

        do {
            try await client.login(identifier: identifier, password: password, customPDSURL: customPDSURL)

            print("✅ Login successful!")
            print("   Session DID: \(client.session?.did ?? "nil")")
            print("   Session Handle: \(client.session?.handle ?? "nil")")

            // Get the logged-in user's profile to save account info
            if let did = client.session?.did {
                // Save credentials to Keychain if user wants to remember
                if rememberMe {
                    try? KeychainService.shared.saveCredentials(identifier: identifier, password: password, for: did)
                }

                // Fetch user profile to get display name and avatar
                do {
                    let profile = try await client.getProfile(actor: did)

                    // Add account to AccountManager
                    accountManager.addAccount(
                        did: did,
                        handle: profile.handle,
                        displayName: profile.displayName,
                        avatar: profile.avatar
                    )
                    print("✅ Added account to AccountManager: \(profile.handle) (DID: \(did))")
                    print("📊 Total accounts: \(accountManager.accounts.count)")
                } catch {
                    // If profile fetch fails, still add account with basic info
                    accountManager.addAccount(
                        did: did,
                        handle: identifier,
                        displayName: nil,
                        avatar: nil
                    )
                    print("✅ Added account with basic info to AccountManager: \(identifier)")
                    print("📊 Total accounts: \(accountManager.accounts.count)")
                }
            }

            isAuthenticated = true

            // Track user login and set user properties
            Analytics.logEvent("login", parameters: [
                "method": "bluesky"
            ])
            Analytics.setUserProperty(identifier, forName: "user_handle")
            print("📊 Analytics: Logged login event for user: \(identifier)")

            isLoading = false
            print("🔓 Login process complete. isAuthenticated: \(isAuthenticated), errorMessage: \(errorMessage ?? "nil")")
            return true  // Login succeeded
        } catch {
            print("❌ Login failed with error: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            print("🔓 Login process complete. isAuthenticated: \(isAuthenticated), errorMessage: \(errorMessage ?? "nil")")
            return false  // Login failed
        }
    }

    func logout() {
        // Get the current account ID before logging out
        if let accountId = accountManager.activeAccountId {
            // Remove account from AccountManager
            accountManager.removeAccount(did: accountId)
        }

        client.logout()

        // Check if there are any accounts left
        if accountManager.accounts.isEmpty {
            isAuthenticated = false
        } else {
            // If there are other accounts, switch to the first one
            if accountManager.activeAccountId != nil,
               let credentials = KeychainService.shared.retrieveCredentials() {
                // Re-login with the next account's credentials
                Task {
                    _ = await login(identifier: credentials.identifier, password: credentials.password, rememberMe: true)
                }
            } else {
                isAuthenticated = false
            }
        }
    }

    func getSavedCredentials() -> (identifier: String, password: String)? {
        return KeychainService.shared.retrieveCredentials()
    }
}
