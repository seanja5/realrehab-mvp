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

// RPC params for accounts.upsert_patient_lesson_progress. Manual nonisolated encode to satisfy Sendable.
struct UpsertLessonProgressParams: Encodable, Sendable {
    let p_lesson_id: String
    let p_reps_completed: Int
    let p_reps_target: Int
    let p_elapsed_seconds: Int
    let p_status: String

    private enum CodingKeys: String, CodingKey {
        case p_lesson_id, p_reps_completed, p_reps_target, p_elapsed_seconds, p_status
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_lesson_id, forKey: .p_lesson_id)
        try container.encode(p_reps_completed, forKey: .p_reps_completed)
        try container.encode(p_reps_target, forKey: .p_reps_target)
        try container.encode(p_elapsed_seconds, forKey: .p_elapsed_seconds)
        try container.encode(p_status, forKey: .p_status)
    }
}

// RPC params for accounts.delete_patient_lesson_progress. Manual nonisolated encode to satisfy Sendable.
struct DeleteLessonProgressParams: Encodable, Sendable {
    let p_lesson_id: String

    private enum CodingKeys: String, CodingKey {
        case p_lesson_id
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_lesson_id, forKey: .p_lesson_id)
    }
}
