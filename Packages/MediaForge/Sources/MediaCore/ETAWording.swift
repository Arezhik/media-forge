import Foundation

/// "About N seconds/minutes/hours left" for a batch ETA.
///
/// MKVForge and MP4SubRip share this wording. Each app still computes how many
/// seconds are left. A rounded 0 is shown as 1 second. Negative, infinite, or
/// non-finite values are blank.
public enum ETAWording {
    public static func sentence(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "" }
        let rounded = Int(seconds.rounded())
        if rounded < 60 {
            let count = max(1, rounded)
            return count == 1 ? "About 1 second left" : "About \(count) seconds left"
        }
        let minutesTotal = Int((Double(rounded) / 60).rounded())
        if minutesTotal < 60 {
            return minutesTotal == 1 ? "About 1 minute left" : "About \(minutesTotal) minutes left"
        }
        let hours = minutesTotal / 60
        let minutes = minutesTotal % 60
        let hourWord = hours == 1 ? "hour" : "hours"
        if minutes == 0 {
            return "About \(hours) \(hourWord) left"
        }
        let minuteWord = minutes == 1 ? "minute" : "minutes"
        return "About \(hours) \(hourWord) \(minutes) \(minuteWord) left"
    }
}
