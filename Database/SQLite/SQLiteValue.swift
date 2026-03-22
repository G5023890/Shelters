import Foundation

enum SQLiteValue: Hashable, Sendable {
    case integer(Int64)
    case double(Double)
    case text(String)
    case null

    static func bool(_ value: Bool) -> SQLiteValue {
        .integer(value ? 1 : 0)
    }
}

