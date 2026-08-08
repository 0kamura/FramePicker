import Foundation

public struct PersistedSession: Codable, Equatable, Sendable {
    public let sourceID: String
    public var capturedTimes: [Double]

    public init(sourceID: String, capturedTimes: [Double]) {
        self.sourceID = sourceID
        self.capturedTimes = capturedTimes
    }
}

public enum ExportNaming {
    public static func filename(index: Int, totalCount: Int) -> String {
        let digits = max(3, String(max(totalCount, 1)).count)
        return String(format: "%0*d.png", digits, index + 1)
    }

    public static func folderName(date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "FramePicker-%04d%02d%02d-%02d%02d%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            parts.hour ?? 0,
            parts.minute ?? 0,
            parts.second ?? 0
        )
    }
}
