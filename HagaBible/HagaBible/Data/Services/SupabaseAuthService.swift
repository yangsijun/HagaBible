//
//  SupabaseAuthService.swift
//  HagaBible
//
//  Supabase-backed `AuthService`. Sign in with Apple uses the native id-token
//  flow: the app obtains an Apple identity token (with SHA256(nonce) baked in)
//  and exchanges it, plus the raw nonce, for a Supabase session. The user id is
//  normalised to a lowercased UUID string to match Postgres `auth.uid()`.
//

import Foundation
import Supabase

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUserId: String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }

    @discardableResult
    func signInWithApple(idToken: String, rawNonce: String) async throws -> String {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
        return session.user.id.uuidString.lowercased()
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
