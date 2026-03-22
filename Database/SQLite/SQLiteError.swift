import Foundation

enum SQLiteError: LocalizedError {
    case openDatabase(path: String, message: String)
    case execute(sql: String, message: String)
    case prepare(sql: String, message: String)
    case bind(sql: String, index: Int32, message: String)
    case transaction(message: String)
    case missingColumn(String)
    case invalidValue(column: String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let path, let message):
            return "Failed to open database at \(path): \(message)"
        case .execute(let sql, let message):
            return "SQLite execution failed for '\(sql)': \(message)"
        case .prepare(let sql, let message):
            return "SQLite prepare failed for '\(sql)': \(message)"
        case .bind(let sql, let index, let message):
            return "SQLite bind failed at index \(index) for '\(sql)': \(message)"
        case .transaction(let message):
            return "SQLite transaction failed: \(message)"
        case .missingColumn(let column):
            return "Missing SQLite column '\(column)'"
        case .invalidValue(let column):
            return "Invalid SQLite value for column '\(column)'"
        }
    }
}

