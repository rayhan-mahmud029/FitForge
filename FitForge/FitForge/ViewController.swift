import UIKit

final class ViewController: UIViewController, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!

    private var workouts: [Workout] = []
    private let client = WGERClient()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExerciseCell")

        // OPTION A: single muscle
        // let muscleIDs = [1] // biceps

        // OPTION B: fetch for many muscles (first 10 ids 1...10)
        let muscleIDs = Array(1...10)

        client.fetchExercises(for: muscleIDs, maxPerMuscle: 10) { [weak self] fetched in
            print("🎉 fetched \(fetched.count) exercises")
            self?.workouts = fetched
            self?.tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("🔢 numberOfRowsInSection:", workouts.count)
        return workouts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("✅ cellForRowAt:", indexPath.row)
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath)
        let w = workouts[indexPath.row]
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.text = w.name.isEmpty ? "Exercise \(w.id)" : w.name
        return cell
    }
}
