import UIKit

final class ExerciseCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var thumbImageView: UIImageView!

    private var imageTask: URLSessionDataTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.numberOfLines = 2
        subtitleLabel.numberOfLines = 0
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        accessoryType = .disclosureIndicator
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel(); imageTask = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        thumbImageView.image = nil
    }

    func configure(with workout: Workout) {
        // Title
        let cleanedName = (workout.name ?? "")
            .strippedHTML()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.text = cleanedName.isEmpty ? "Unnamed" : cleanedName

        // Description
        let cleanedDesc = (workout.description ?? "")
            .strippedHTML()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        subtitleLabel.text = cleanedDesc

        // Image
        thumbImageView.image = UIImage(named: "exercise_placeholder") // add any placeholder image to Assets
        if let urlString = workout.imageURL, let url = URL(string: urlString) {
            loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) {
        imageTask?.cancel()
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { self.thumbImageView.image = img }
        }
        imageTask?.resume()
    }
}

// Only used internally by this file; API Ninjas text is already plain, but this is safe.
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
