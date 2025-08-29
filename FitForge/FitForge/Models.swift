//
//  Models.swift
//  FitForge
//

import Foundation

/// The app’s display model for an exercise/workout row.
/// Built from API Ninjas + (optionally) a Pexels image.
struct Workout: Codable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let description: String?
    /// We’re not using numeric muscle IDs anymore (API Ninjas uses strings),
    /// so this stays optional. It’s fine for this to be `nil`.
    let muscles: [Int]?
    /// Remote image URL (from Pexels search) or `nil` if none found.
    let imageURL: String?

    // Optional local recommendations
    let recommendedSets: Int?
    let recommendedReps: Int?
}

/// (Optional) A saved plan for a given day.
/// Safe to keep if you plan to persist user routines later.
struct WorkoutPlan: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    var workouts: [Workout]
}

/// (Optional) A single completion entry for history/logs.
struct WorkoutHistoryEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let workout: Workout
    let completedSets: Int
    let completedReps: Int
}
