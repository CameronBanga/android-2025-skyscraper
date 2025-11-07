//
//  LoginView.swift
//  Skyscraper
//
//  Clean, polished login screen
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showAdvanced = false
    @State private var customPDSURL = ""
    @FocusState private var focusedField: Field?
    @State private var isAppeared = false

    let isAddingAccount: Bool

    enum Field: Hashable {
        case identifier, password, customPDS
    }

    init(isAddingAccount: Bool = false) {
        self.isAddingAccount = isAddingAccount
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Close button for adding account
                if isAddingAccount {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding()
                        }
                    }
                } else {
                    Spacer()
                }

                // App icon and title
                VStack(spacing: 16) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .scaleEffect(isAppeared ? 1 : 0.5)
                        .opacity(isAppeared ? 1 : 0)

                    Text(isAddingAccount ? "Add Account" : "Skyscraper")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(isAppeared ? 1 : 0)
                        .offset(y: isAppeared ? 0 : 20)

                    Text(isAddingAccount ? "Sign in with another BlueSky account" : "A BlueSky Client")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .opacity(isAppeared ? 1 : 0)
                        .offset(y: isAppeared ? 0 : 20)
                }
                .padding(.bottom, 40)

                // Login form
                VStack(spacing: 16) {
                    TextField("Username or email", text: $identifier)
                        #if os(iOS)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        #endif
                        .focused($focusedField, equals: .identifier)
                        .padding()
                        #if os(iOS)
                        .background(Color(uiColor: .systemBackground))
                        #else
                        .background(Color(nsColor: .controlBackgroundColor))
                        #endif
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                    SecureField("App Password", text: $password)
                        #if os(iOS)
                        .textContentType(.password)
                        #endif
                        .focused($focusedField, equals: .password)
                        .padding()
                        #if os(iOS)
                        .background(Color(uiColor: .systemBackground))
                        #else
                        .background(Color(nsColor: .controlBackgroundColor))
                        #endif
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .submitLabel(.go)
                        .onSubmit {
                            Task {
                                await login()
                            }
                        }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    // Remember Me toggle
                    Toggle(isOn: $rememberMe) {
                        Text("Remember me")
                            .font(.subheadline)
                    }
                    .tint(.white)

                    // Advanced options
                    DisclosureGroup(
                        isExpanded: $showAdvanced,
                        content: {
                            VStack(spacing: 12) {
                                Text("Enter a custom PDS server URL. Leave blank to use the default (bsky.social).")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                TextField("Custom PDS URL", text: $customPDSURL)
                                    #if os(iOS)
                                    .textContentType(.URL)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                    #endif
                                    .focused($focusedField, equals: .customPDS)
                                    .padding()
                                    #if os(iOS)
                                    .background(Color(uiColor: .systemBackground))
                                    #else
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    #endif
                                    .foregroundStyle(.primary)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .accentColor(.orange)
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            Text("Advanced")
                                .font(.subheadline)
                        }
                    )
                    .tint(.white)

                    Button {
                        Task {
                            await login()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(Color.orange)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.isLoading || identifier.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 40)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 30)

                // Help text
                VStack(spacing: 8) {
                    Text("Use your BlueSky handle and app password")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Button {
                        if let url = URL(string: "https://bsky.app/settings/app-passwords") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        Text("Create app password")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .underline()
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppeared = true
            }

            // Load saved credentials only if not adding an account
            if !isAddingAccount, let credentials = viewModel.getSavedCredentials() {
                identifier = credentials.identifier
                password = credentials.password
                rememberMe = true
            }
        }
    }

    private func login() async {
        focusedField = nil

        // Use custom PDS URL if provided, otherwise nil (will default to bsky.social)
        let pdsURL = customPDSURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customPDSURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let success = await viewModel.login(identifier: identifier, password: password, rememberMe: rememberMe, customPDSURL: pdsURL)

        // Dismiss the modal if adding an account and THIS login was successful
        if isAddingAccount && success {
            dismiss()
        }
    }
}

#Preview {
    LoginView()
}
