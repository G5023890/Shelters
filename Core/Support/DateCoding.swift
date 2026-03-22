import Foundation

enum DateCoding {
    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }

    static func string(from date: Date) -> String {
        formatter().string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter().date(from: string)
    }
}
