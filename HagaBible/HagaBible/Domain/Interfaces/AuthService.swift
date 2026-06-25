//
//  AuthService.swift
//  HagaBible
//
//  Identity provider backing remote sync: Sign in with Apple → Supabase Auth.
//  `currentUserId` is the Supabase `auth.uid()` (lowercased UUID string) used to
//  scope synced rows; it is nil while signed out (local-only mode).
//

import Foundation
import CryptoKit

protocol AuthService: AnyObject, Sendable {
    /// Supabase user id of the active session, or nil when signed out.
    var currentUserId: String? { get }

    /// Exchange an Apple identity token for a Supabase session. `rawNonce` is the
    /// un-hashed nonce whose SHA256 was set on the Apple request — Supabase needs
    /// the raw value to verify the token's `nonce` claim. Returns the user id.
    @discardableResult
    func signInWithApple(idToken: String, rawNonce: String) async throws -> String

    func signOut() async throws
}

/// Nonce helpers for the Sign in with Apple replay-protection flow: a random raw
/// nonce is generated, its SHA256 is handed to Apple, and the raw value is later
/// handed to Supabase. A mismatch fails verification, which is the point.
enum AppleSignInNonce {
    /// Cryptographically-random nonce string (URL-safe characters).
    static func randomRawNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            result.append(charset[Int(random) % charset.count])
            remaining -= 1
        }
        return result
    }

    /// SHA256 hex digest of the raw nonce — the value sent to Apple.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
