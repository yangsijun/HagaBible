//
//  SyncAccountViewModel.swift
//  HagaBible
//
//  Owns the Sign in with Apple → Supabase flow and the foreground sync trigger.
//  Generates the replay-protection nonce (SHA256 to Apple, raw to Supabase),
//  drives `SyncEngine`, and — on an *account switch* — wipes local user data so
//  a second account on the same device starts clean. Account identity is
//  remembered across launches so a same-account re-login skips the wipe.
//

import Foundation
import Observation

@Observable
final class SyncAccountViewModel {
    enum Status: Equatable {
        case signedOut
        case signingIn
        case signedIn
        case syncing
        case error(String)
    }

    private(set) var status: Status
    private(set) var currentUserId: String?

    private let authService: AuthService
    private let syncEngine: SyncEngine

    /// Raw nonce for the in-flight Apple request; its SHA256 was sent to Apple.
    private var pendingRawNonce: String?

    /// Persisted id of the last account that synced on this device — used to
    /// detect account switches across launches.
    private static let lastUserDefaultsKey = "sync.lastSyncedUserId"

    init(authService: AuthService, syncEngine: SyncEngine) {
        self.authService = authService
        self.syncEngine = syncEngine
        if let uid = authService.currentUserId {
            self.currentUserId = uid
            self.status = .signedIn
        } else {
            self.status = .signedOut
        }
    }

    var isSignedIn: Bool { authService.currentUserId != nil }

    // MARK: - Sign in with Apple

    /// Prepare a fresh nonce and return the SHA256 digest to set on the Apple
    /// request (`ASAuthorizationAppleIDRequest.nonce`).
    func makeAppleRequestNonce() -> String {
        let raw = AppleSignInNonce.randomRawNonce()
        pendingRawNonce = raw
        return AppleSignInNonce.sha256(raw)
    }

    /// Exchange the Apple identity token for a Supabase session, then sync.
    func completeAppleSignIn(idToken: String) async {
        guard let rawNonce = pendingRawNonce else {
            status = .error("Sign-in request expired. Please try again.")
            return
        }
        status = .signingIn
        do {
            let userId = try await authService.signInWithApple(idToken: idToken, rawNonce: rawNonce)
            pendingRawNonce = nil
            currentUserId = userId
            try await handleAccountChange(to: userId)
            status = .signedIn
            await sync()
        } catch {
            pendingRawNonce = nil
            status = .error(error.localizedDescription)
        }
    }

    /// Apple flow ended without a session (commonly user cancellation). Don't
    /// surface cancellations as errors.
    func appleSignInFailed() {
        pendingRawNonce = nil
        status = isSignedIn ? .signedIn : .signedOut
    }

    // MARK: - Sync

    /// Sync if signed in. Safe to call on foreground / scenePhase `.active`.
    func sync() async {
        guard let userId = authService.currentUserId else { return }
        status = .syncing
        do {
            try await syncEngine.sync(userId: userId)
            persistLastUser(userId)
            status = .signedIn
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func signOut() async {
        try? await authService.signOut()
        currentUserId = nil
        status = .signedOut
    }

    // MARK: - Account switch

    /// If a *different* account just signed in (vs. the last one that synced on
    /// this device), wipe local data so the previous account's rows can't bleed
    /// into — or be re-uploaded under — the new account. A first-ever sign-in
    /// (no prior account) keeps local data so pre-existing bookmarks migrate up.
    private func handleAccountChange(to userId: String) async throws {
        let previous = UserDefaults.standard.string(forKey: Self.lastUserDefaultsKey)
        if let previous, previous != userId {
            try await syncEngine.clearLocalUserData()
        }
    }

    private func persistLastUser(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: Self.lastUserDefaultsKey)
    }
}
