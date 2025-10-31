//
//  SupabaseService.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/30/25.
//

import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient

    private init() {
        // Load values from SupabaseConfig.plist in the app bundle
        guard
            let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let urlString = dict["SUPABASE_URL"] as? String,
            let key = dict["SUPABASE_ANON_KEY"] as? String,
            let supabaseURL = URL(string: urlString)
        else {
            fatalError("Could not load SupabaseConfig.plist or keys")
        }

        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
        print("✅ Supabase initialized")
    }
}
