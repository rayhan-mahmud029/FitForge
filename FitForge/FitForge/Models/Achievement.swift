import Foundation

struct Achievement: Codable {
  let id: UUID
  let title: String
  let description: String
  var unlocked: Bool
}
