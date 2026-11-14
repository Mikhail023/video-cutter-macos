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
}
