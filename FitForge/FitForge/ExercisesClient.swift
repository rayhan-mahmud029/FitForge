import Foundation

// MARK: - Read API keys from Info.plist
// Add these keys to Info.plist (String):
//  - NINJAS_API_KEY
//  - PEXELS_API_KEY  (optional; if empty, you'll still see text with a placeholder image)
private let NINJAS_API_KEY: String = {
    (Bundle.main.object(forInfoDictionaryKey: "NINJAS_API_KEY") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}()

private let PEXELS_API_KEY: String = {
    (Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}()

// MARK: - API Ninjas models
private struct NinjasExercise: Decodable {
    let name: String
    let type: String?
    let muscle: String?
    let equipment: String?
    let difficulty: String?
    let instructions: String?
}

// MARK: - Pexels models (per docs)
private struct PexelsSearchResponse: Decodable {
    let photos: [PexelsPhoto]
}

private struct PexelsPhoto: Decodable {
    let src: PexelsSrc
    let alt: String?
}

private struct PexelsSrc: Decodable {
    let original: String
    let large2x: String?
    let large: String?
    let medium: String?
    let small: String?
    let portrait: String?
    let landscape: String?
    let tiny: String?
}

// MARK: - Client
final class ExercisesClient {

    private let ninjasBase = URL(string: "https://api.api-ninjas.com/v1")!

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 20
        cfg.httpMaximumConnectionsPerHost = 3      // keep it light
        return URLSession(configuration: cfg)
    }()

    // tiny in-memory cache so we don’t search Pexels twice for the same exercise
    private var imageCache: [String: String] = [:]
    private let cacheLock = NSLock()

    /// Fetch up to `perMuscle` exercises for each muscle name (ex: "chest", "biceps")
    /// Then (optionally) attach one Pexels image per exercise.
    func fetchTopExercises(for muscles: [String], perMuscle: Int = 5, completion: @escaping ([Workout]) -> Void) {
        let outer = DispatchGroup()
        var all: [Workout] = []
        let allLock = NSLock()

        for muscle in muscles {
            outer.enter()
            fetchNinjasExercises(muscle: muscle, limit: perMuscle) { [weak self] items in
                guard let self else { outer.leave(); return }

                // If no Pexels key, skip images entirely
                guard !PEXELS_API_KEY.isEmpty else {
                    let mapped = items.map { self.mapToWorkout($0, muscleName: muscle, imageURL: nil) }
                    allLock.lock(); all.append(contentsOf: mapped); allLock.unlock()
                    outer.leave()
                    return
                }

                // With Pexels: fetch 1 image per exercise (kept small -> fast)
                let inner = DispatchGroup()
                var bucket: [Workout] = []
                let bucketLock = NSLock()

                for ex in items {
                    inner.enter()
                    self.firstPexelsImage(for: ex.name) { url in
                        let w = self.mapToWorkout(ex, muscleName: muscle, imageURL: url)
                        bucketLock.lock(); bucket.append(w); bucketLock.unlock()
                        inner.leave()
                    }
                }

                inner.notify(queue: .global(qos: .userInitiated)) {
                    allLock.lock(); all.append(contentsOf: bucket); allLock.unlock()
                    outer.leave()
                }
            }
        }

        outer.notify(queue: .main) {
            completion(all)
        }
    }

    // MARK: - Ninjas
    private func fetchNinjasExercises(muscle: String, limit: Int, done: @escaping ([NinjasExercise]) -> Void) {
        var comp = URLComponents(url: ninjasBase.appendingPathComponent("exercises"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            .init(name: "muscle", value: muscle)
            // API Ninjas returns an array; no per_page param. We'll slice locally.
        ]

        guard let url = comp.url else { return done([]) }
        var req = URLRequest(url: url)
        req.setValue(NINJAS_API_KEY, forHTTPHeaderField: "X-Api-Key")

        session.dataTask(with: req) { data, _, error in
            guard let data, error == nil else { return done([]) }
            do {
                let arr = try JSONDecoder().decode([NinjasExercise].self, from: data)
                let filtered = arr.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                done(Array(filtered.prefix(limit)))
            } catch {
                done([])
            }
        }.resume()
    }

    // MARK: - Pexels (optional)
    private func firstPexelsImage(for exerciseName: String, done: @escaping (String?) -> Void) {
        // cache hit
        cacheLock.lock()
        if let cached = imageCache[exerciseName] {
            cacheLock.unlock(); return done(cached)
        }
        cacheLock.unlock()

        guard !PEXELS_API_KEY.isEmpty else { return done(nil) }

        var comp = URLComponents(string: "https://api.pexels.com/v1/search")!
        comp.queryItems = [
            .init(name: "query", value: "\(exerciseName) gym exercise"),
            .init(name: "per_page", value: "1"),
            .init(name: "orientation", value: "landscape")
        ]

        guard let url = comp.url else { return done(nil) }
        var req = URLRequest(url: url)
        req.setValue(PEXELS_API_KEY, forHTTPHeaderField: "Authorization")

        session.dataTask(with: req) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return done(nil) }
            do {
                let res = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
                // Prefer large/landscape > medium > tiny
                let first = res.photos.first
                let src = first?.src
                let pick = src?.landscape ?? src?.large ?? src?.medium ?? src?.tiny ?? src?.original
                if let pick {
                    self.cacheLock.lock(); self.imageCache[exerciseName] = pick; self.cacheLock.unlock()
                }
                done(pick)
            } catch {
                done(nil)
            }
        }.resume()
    }

    // MARK: - Map into your app's Workout model
    private func mapToWorkout(_ ex: NinjasExercise, muscleName: String, imageURL: String?) -> Workout {
        // deterministic id
        let key = (ex.name + "|" + (ex.muscle ?? muscleName)).lowercased()
        let id = abs(key.hashValue)

        return Workout(
            id: id,
            name: ex.name,
            description: ex.instructions,
            muscles: nil,              // API Ninjas uses string muscles; keep nil in your int-based model
            imageURL: imageURL,
            recommendedSets: nil,
            recommendedReps: nil
        )
    }
}
