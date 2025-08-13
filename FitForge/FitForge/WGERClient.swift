import Foundation


final class WGERClient {
    private let token = "51b6efba8d367af9a06572881f2848f8ae8f163d"
    private let baseURL = URL(string: "https://wger.de/api/v2")!
    private let session = URLSession.shared
    private let langEN = 2

    // MARK: - Public API

    /// Convenience: single muscle
    func fetchExercises(for muscleID: Int, completion: @escaping ([Workout]) -> Void) {
        fetchExercises(for: [muscleID], maxPerMuscle: 20, completion: completion)
    }

    /// Fetch exercises for multiple muscle IDs, deduping by exercise id
    func fetchExercises(for muscleIDs: [Int], maxPerMuscle: Int = 20, completion: @escaping ([Workout]) -> Void) {
        // 1) Get minimal lists for each muscle (exercise ids + muscles)
        let group = DispatchGroup()
        var idToMuscles: [Int: Set<Int>] = [:]  // accumulate muscles for same exercise id
        var allIDs: Set<Int> = []

        for mID in muscleIDs {
            group.enter()
            fetchMinimalExercises(forMuscle: mID, limit: maxPerMuscle) { minis in
                for mini in minis {
                    allIDs.insert(mini.id)
                    var set = idToMuscles[mini.id] ?? []
                    mini.muscles?.forEach { set.insert($0) }
                    idToMuscles[mini.id] = set
                }
                group.leave()
            }
        }

        // 2) After we know unique ids, fetch details per id (correct endpoint)
        group.notify(queue: .global(qos: .userInitiated)) {
            self.fetchDetails(forIDs: Array(allIDs), idToMuscles: idToMuscles) { workouts in
                DispatchQueue.main.async {
                    completion(workouts)
                }
            }
        }
    }

    // MARK: - Step 1: minimal list (ids + muscles)
    private struct MinimalExercise: Decodable {
        let id: Int
        let muscles: [Int]?
    }
    private struct MinimalWrap: Decodable { let results: [MinimalExercise] }

    private func fetchMinimalExercises(forMuscle muscleID: Int, limit: Int, completion: @escaping ([MinimalExercise]) -> Void) {
        var comp = URLComponents(url: baseURL.appendingPathComponent("exercise/"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "muscles", value: "\(muscleID)"),
            URLQueryItem(name: "language", value: "\(langEN)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = comp.url else { completion([]); return }

        var req = URLRequest(url: url)
        req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: req) { data, _, err in
            guard let data = data else { print("❌ minimal list error:", err ?? "Unknown"); return completion([]) }
            do {
                let wrap = try JSONDecoder().decode(MinimalWrap.self, from: data)
                completion(wrap.results)
            } catch {
                print("❌ minimal decode error:", error)
                completion([])
            }
        }.resume()
    }

    // MARK: - Step 2: details via /exerciseinfo/{id}/?language=2

    private struct InfoImage: Decodable {
        let image: String
        let is_main: Bool
    }
    private struct InfoTranslation: Decodable {
        let language: Int
        let name: String
        let description: String
    }
    private struct InfoDetail: Decodable {
        let id: Int
        let images: [InfoImage]
        let translations: [InfoTranslation]
    }

    private func fetchDetails(forIDs ids: [Int],
                              idToMuscles: [Int: Set<Int>],
                              completion: @escaping ([Workout]) -> Void) {
        let group = DispatchGroup()
        var workouts: [Workout] = []
        let lock = NSLock()

        for id in ids {
            group.enter()
            // Correct detail endpoint (NOT the list with a bogus query param)
            var components = URLComponents(url: baseURL.appendingPathComponent("exerciseinfo/\(id)/"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "language", value: "\(langEN)")]
            guard let url = components.url else { group.leave(); continue }

            var req = URLRequest(url: url)
            req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

            session.dataTask(with: req) { data, _, err in
                defer { group.leave() }
                guard let data = data else { print("❌ info \(id) error:", err ?? "Unknown"); return }

                do {
                    let info = try JSONDecoder().decode(InfoDetail.self, from: data)

                    // Pick English translation when possible
                    let tr = info.translations.first(where: { $0.language == self.langEN }) ?? info.translations.first
                    let rawName = tr?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let rawDesc = tr?.description ?? ""
                    let name = rawName.isEmpty ? "Exercise \(id)" : rawName
                    let desc = Self.stripHTML(rawDesc)

                    // Pick main image when present
                    let img = info.images.first(where: { $0.is_main })?.image ?? info.images.first?.image

                    let muscles = Array(idToMuscles[id] ?? [])
                    let workout = Workout(
                        id: id,
                        name: name,
                        description: desc,
                        muscles: muscles, // pass [] if empty; safe for `[Int]` and `[Int]?`
                        imageURL: img,
                        recommendedSets: nil,
                        recommendedReps: nil
                    )

                    lock.lock()
                    workouts.append(workout)
                    lock.unlock()
                } catch {
                    print("❌ info decode \(id) error:", error)
                }
            }.resume()
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            // Sort for stable UI (by name)
            let sorted = workouts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            completion(sorted)
        }
    }

    // MARK: - Utils

    private static func stripHTML(_ html: String) -> String {
        // simple & fast: remove tags
        let noTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
        // collapse whitespace
        return noTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
