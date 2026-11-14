import Foundation

enum VideoTimeFormatter {
    static func string(for seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainingSeconds = total % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func parse(_ value: String) -> TimeInterval? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if normalized.contains(":") {
            let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
            guard (2...3).contains(parts.count), parts.allSatisfy({ Double($0) != nil }) else { return nil }
            let values = parts.compactMap { Double($0) }
            guard values.dropFirst().allSatisfy({ $0 >= 0 && $0 < 60 }) else { return nil }
            return values.reduce(0) { $0 * 60 + $1 }
        }
        guard let seconds = Double(normalized), seconds >= 0 else { return nil }
        return seconds
    }

    static func editString(for seconds: TimeInterval) -> String {
        let safeSeconds = max(seconds.isFinite ? seconds : 0, 0)
        let whole = Int(safeSeconds)
        let fraction = safeSeconds - Double(whole)
        let centiseconds = Int((fraction * 100).rounded())
        let adjustedSeconds = whole + centiseconds / 100
        let remainder = centiseconds % 100
        let hours = adjustedSeconds / 3_600
        let minutes = (adjustedSeconds % 3_600) / 60
        let secs = adjustedSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secs, remainder)
        }
        return String(format: "%02d:%02d.%02d", minutes, secs, remainder)
    }
}
