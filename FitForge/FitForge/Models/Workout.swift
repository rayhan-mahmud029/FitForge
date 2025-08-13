import Foundation

// MARK: - Workout & Supporting Models

struct Workout: Codable {
    let id: Int
    let name: String
    let description: String
    let muscles: [Int]
    let imageURL: String?  // you can implement fetchImages later
    let recommendedSets: Int?  // if you wire up plans
    let recommendedReps: Int?
}

struct Muscle: Codable {
    let id: Int
    let name: String
}

// close FullExerciseInfo
struct ExerciseImage: Decodable {
    let id: Int
    let exercise: Int  // workout ID
    let image: String  // URL string
}

struct WorkoutPlan: Codable {
    let id: UUID
    let date: Date
    var workouts: [Workout]
}

struct WorkoutHistoryEntry: Codable {
    let id: UUID
    let date: Date
    let workout: Workout
    let completedSets: Int
    let completedReps: Int
}
/// One table section = one muscle group
struct MuscleSection {
    let id: Int
    let title: String
    var exercises: [Workout]
}
