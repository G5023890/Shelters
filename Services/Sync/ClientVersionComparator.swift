import Foundation

enum ClientVersionComparator {
    static func isSupported(current: String, minimumRequired: String) -> Bool {
        compare(current, minimumRequired) != .orderedAscending
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = normalize(lhs)
        let rhsParts = normalize(rhs)
        let maxCount = max(lhsParts.count, rhsParts.count)

        for index in 0..<maxCount {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue < rhsValue {
                return .orderedAscending
            }

            if lhsValue > rhsValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func normalize(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { component in
                Int(component.prefix { $0.isNumber }) ?? 0
            }
    }
}
