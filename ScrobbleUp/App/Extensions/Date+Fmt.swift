import Foundation

extension Date {
  func shortHuman() -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df.string(from: self)
  }
}
