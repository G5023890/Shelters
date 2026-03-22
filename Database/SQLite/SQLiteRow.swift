import Foundation

struct SQLiteRow: Sendable {
    private let storage: [String: SQLiteValue]

    init(storage: [String: SQLiteValue]) {
        self.storage = storage
    }

    func string(_ column: String) -> String? {
        guard let value = storage[column] else { return nil }
        switch value {
        case .text(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .double(let double):
            return String(double)
        case .null:
            return nil
        }
    }

    func double(_ column: String) -> Double? {
        guard let value = storage[column] else { return nil }
        switch value {
        case .double(let double):
            return double
        case .integer(let integer):
            return Double(integer)
        case .text(let string):
            return Double(string)
        case .null:
            return nil
        }
    }

    func int64(_ column: String) -> Int64? {
        guard let value = storage[column] else { return nil }
        switch value {
        case .integer(let integer):
            return integer
        case .double(let double):
            return Int64(double)
        case .text(let string):
            return Int64(string)
        case .null:
            return nil
        }
    }

    func bool(_ column: String) -> Bool? {
        int64(column).map { $0 != 0 }
    }
}

