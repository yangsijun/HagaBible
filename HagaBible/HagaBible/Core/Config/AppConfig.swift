//
//  AppConfig.swift
//  HagaBible
//
//  Static app configuration for the remote-sync backend. The Supabase project
//  URL is a public endpoint and is hard-coded. The anon (publishable) key is
//  injected at build time from `Secrets.xcconfig` (gitignored) → the build
//  setting `SUPABASE_ANON_KEY` → Info.plist `SupabaseAnonKey`, so the key never
//  lands in version control. The anon key is safe to ship in the client by
//  design; injection is defense-in-depth to keep it out of the public repo.
//

import Foundation

enum AppConfig {
    /// Supabase project endpoint. Public, safe to embed.
    static let supabaseURL = URL(string: "https://xvssaydpzuktneqvjcin.supabase.co")!

    /// Supabase anon/publishable key, read from Info.plist (`SupabaseAnonKey`),
    /// which is populated from the `SUPABASE_ANON_KEY` build setting.
    static var supabaseAnonKey: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String) ?? ""
        // Guard against an unexpanded `$(SUPABASE_ANON_KEY)` placeholder when the
        // secret isn't configured (e.g. a fresh checkout without Secrets.xcconfig).
        return raw.hasPrefix("$(") ? "" : raw
    }

    /// Whether remote sync can be attempted at all (the anon key is present).
    /// When false, the app stays fully functional in local-only mode.
    static var isSupabaseConfigured: Bool { !supabaseAnonKey.isEmpty }
}
