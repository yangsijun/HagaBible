//
//  SupabaseClientProvider.swift
//  HagaBible
//
//  Builds the shared `SupabaseClient` from `AppConfig`. Registered once in the
//  DI container and shared by `SupabaseAuthService` and
//  `SupabaseRemoteSyncDataSource` so auth state and PostgREST requests ride the
//  same session (the client attaches the signed-in user's JWT automatically).
//

import Foundation
import Supabase

enum SupabaseClientProvider {
    /// Construct a client for the configured project. Callers should guard on
    /// `AppConfig.isSupabaseConfigured` first; with an empty key the client still
    /// builds but every request 401s.
    static func make() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey,
            // Opt in to the next-major default (supabase/supabase-swift#822): emit the
            // locally stored session as the initial session instead of refreshing it
            // first. This silences the runtime warning AuthClient logs under the legacy
            // default. Safe here — we read `auth.currentUser` synchronously and never
            // subscribe to `authStateChanges`/`.initialSession`, so there's no opt-in
            // logic that would need an extra `session.isExpired` check; token refresh
            // still happens in the background via `autoRefreshToken` (default on).
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
