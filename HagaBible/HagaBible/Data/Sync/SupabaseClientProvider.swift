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
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }
}
