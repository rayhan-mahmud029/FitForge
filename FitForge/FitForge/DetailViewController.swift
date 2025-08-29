//
//  DetailViewController.swift
//  FitForge
//
//  Created by Rezwan Mahmud on 8/28/25.
//

import UIKit

class DetailViewController: UIViewController {
    var exercise: Workout?

    @IBOutlet weak var topImage: UIImageView!
    
    @IBOutlet weak var exerciseName: UILabel!
    
    @IBOutlet weak var exerciseDescription: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let exercise = exercise else {
            print("❌ Exercise is nil")
            return
        }

        let cleanedName = (exercise.name ?? "")
            .strippedHTML()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        exerciseName.text = cleanedName.isEmpty ? "Unnamed" : cleanedName

        let cleanedDesc = (exercise.description ?? "")
            .strippedHTML()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        exerciseDescription.text = cleanedDesc

        topImage.image = UIImage(named: "exercise_placeholder")
        if let urlString = exercise.imageURL, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.topImage.image = image
                }
            }.resume()
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

private extension String {
    func strippedHTML() -> String {
        guard let data = data(using: .utf8) else { return self }
        if let attr = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return self
    }
}
