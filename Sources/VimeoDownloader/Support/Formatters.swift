import Foundation

@MainActor
enum AppFormatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum ProgressParser {
    static func segmentProgress(from line: String) -> Double? {
        let pattern = #"(\d+)/(\d+)/(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..<line.endIndex, in: line)
              ),
              match.numberOfRanges == 4,
              let completedRange = Range(match.range(at: 2), in: line),
              let totalRange = Range(match.range(at: 3), in: line),
              let completed = Double(line[completedRange]),
              let total = Double(line[totalRange]),
              total > 0 else {
            return nil
        }

        return min(max(completed / total, 0), 1)
    }
}
