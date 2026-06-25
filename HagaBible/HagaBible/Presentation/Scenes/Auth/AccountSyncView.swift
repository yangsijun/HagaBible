//
//  AccountSyncView.swift
//  HagaBible
//
//  Account screen for cross-device sync: Sign in with Apple, sync status, and
//  sign out. Signing in links this device to a Supabase account and syncs
//  bookmarks + reading marks; signing out returns to local-only mode. When the
//  backend isn't configured (no anon key) the screen explains that sync is off.
//

import SwiftUI
import AuthenticationServices

struct AccountSyncView: View {
    @State private var viewModel: SyncAccountViewModel
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    init(viewModel: SyncAccountViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // Styling matches the sibling Labs / Reading Reminders sheets: a transparent
        // form over the themed page background, with accent-tinted controls.
        NavigationStack {
            Form {
                Section {
                    statusRow
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Sign in to sync your bookmarks and reading progress across your devices. Your data stays scoped to your account.")
                }

                if AppConfig.isSupabaseConfigured {
                    if viewModel.isSignedIn {
                        Section {
                            Button {
                                Task { await viewModel.sync() }
                            } label: {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(viewModel.status == .syncing)

                            Button(role: .destructive) {
                                Task { await viewModel.signOut() }
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                            }
                        }
                    } else {
                        Section {
                            signInButton
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .clipShape(Capsule())
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                    }
                } else {
                    Section {
                        Label("Sync is not configured in this build.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Account & Sync")
        }
        .tint(.accent)
        .presentationBackground(Color(uiColor: fontThemeManager.theme.backgroundColor))
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusRow: some View {
        switch viewModel.status {
        case .signedOut:
            Label("Not signed in", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
        case .signingIn:
            Label("Signing in…", systemImage: "person.crop.circle.badge.clock")
        case .signedIn:
            Label("Signed in", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing:
            HStack {
                ProgressView()
                Text("Syncing…")
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = viewModel.makeAppleRequestNonce()
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let idToken = String(data: tokenData, encoding: .utf8)
                else {
                    viewModel.appleSignInFailed()
                    return
                }
                Task { await viewModel.completeAppleSignIn(idToken: idToken) }
            case .failure:
                viewModel.appleSignInFailed()
            }
        }
        .signInWithAppleButtonStyle(.black)
    }
}
