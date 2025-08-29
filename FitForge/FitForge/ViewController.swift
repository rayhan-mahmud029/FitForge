import UIKit

final class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    private var workouts: [Workout] = []
    private let client = ExercisesClient()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        // Make cells tall enough for a visible image
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        // IMPORTANT: In Interface Builder, set the prototype cell's
        // Class = ExerciseCell and Reuse Identifier = "ExerciseCell"

        // Keep it fast: 5 muscles × 5 each = 25 rows
        let muscles = ["chest", "biceps", "triceps"]

        client.fetchTopExercises(for: muscles, perMuscle: 5) { [weak self] items in
            guard let self else { return }
            print("🎉 fetched \(items.count) workouts (Ninjas)")
            self.workouts = items
            self.tableView.reloadData()
        }
    }

    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("🔢 numberOfRowsInSection: \(workouts.count)")
        return workouts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Prototype cell in storyboard must have identifier "ExerciseCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath) as! ExerciseCell
        let w = workouts[indexPath.row]
        cell.configure(with: w)
        return cell
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // MARK: - Pass the selected workout data
        
        // Get the index path for the selected row
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else { return }
        
        // Get the selected workout from the workouts array
        let selectedWorkout = workouts[selectedIndexPath.row]
        
        // Get access to the detail view controller via the segue's destination
        guard let detailVC = segue.destination as? DetailViewController else { return }
        
        detailVC.exercise = selectedWorkout
    }
    
}
