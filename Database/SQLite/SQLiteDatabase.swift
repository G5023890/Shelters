import Dispatch
import Foundation
import SQLite3

final class SQLiteDatabase: @unchecked Sendable {
    private let path: String
    private let queue = DispatchQueue(label: "com.grigorymordokhovich.Shelters.SQLiteDatabase")
    private var handle: OpaquePointer?

    init(path: String) throws {
        self.path = path
        try open()
        try configure()
    }

    deinit {
        queue.sync {
            if let handle {
                sqlite3_close_v2(handle)
            }
        }
    }

    static func inMemory() throws -> SQLiteDatabase {
        try SQLiteDatabase(path: ":memory:")
    }

    func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try queue.sync {
            let connection = try currentConnection()
            try connection.execute(sql, bindings: bindings)
        }
    }

    func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        try queue.sync {
            let connection = try currentConnection()
            return try connection.query(sql, bindings: bindings)
        }
    }

    func transaction(_ block: (SQLiteConnection) throws -> Void) throws {
        try queue.sync {
            let connection = try currentConnection()
            try connection.execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                try block(connection)
                try connection.execute("COMMIT TRANSACTION")
            } catch {
                try? connection.execute("ROLLBACK TRANSACTION")
                throw error
            }
        }
    }

    func reopen() throws {
        try queue.sync {
            try closeCurrentHandle()
            try open()
        }
        try configure()
    }

    func replaceOnDisk(
        using plan: AtomicDatabaseReplacementPlan,
        replacer: AtomicDatabaseReplacing
    ) throws {
        try checkpointWriteAheadLogIfNeeded()

        try queue.sync {
            try closeCurrentHandle()
        }

        do {
            try replacer.replaceDatabase(using: plan)
        } catch {
            try? reopen()
            throw error
        }

        do {
            try queue.sync {
                try open()
            }
            try configure()
        } catch {
            throw SQLiteError.openDatabase(path: path, message: error.localizedDescription)
        }
    }

    private func open() throws {
        var rawHandle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(path, &rawHandle, flags, nil) != SQLITE_OK {
            let message = rawHandle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteError.openDatabase(path: path, message: message)
        }

        handle = rawHandle
    }

    private func configure() throws {
        try execute("PRAGMA foreign_keys = ON;")

        if path != ":memory:" {
            try execute("PRAGMA journal_mode = WAL;")
            try execute("PRAGMA synchronous = NORMAL;")
        }
    }

    private func checkpointWriteAheadLogIfNeeded() throws {
        guard path != ":memory:" else {
            return
        }

        try execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    private func currentConnection() throws -> SQLiteConnection {
        guard let handle else {
            throw SQLiteError.openDatabase(path: path, message: "Database handle is nil")
        }

        return SQLiteConnection(handle: handle)
    }

    private func closeCurrentHandle() throws {
        guard let handle else {
            return
        }

        if sqlite3_close_v2(handle) != SQLITE_OK {
            throw SQLiteError.openDatabase(path: path, message: "Database handle could not be closed")
        }

        self.handle = nil
    }
}

struct SQLiteConnection {
    let handle: OpaquePointer

    func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, sql: sql)

        while true {
            let result = sqlite3_step(statement)

            if result == SQLITE_ROW {
                continue
            }

            if result == SQLITE_DONE {
                return
            }

            throw SQLiteError.execute(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement, sql: sql)

        var rows: [SQLiteRow] = []

        while true {
            let result = sqlite3_step(statement)

            if result == SQLITE_ROW {
                let columnCount = sqlite3_column_count(statement)
                var storage: [String: SQLiteValue] = [:]

                for index in 0..<columnCount {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    storage[name] = value(at: index, in: statement)
                }

                rows.append(SQLiteRow(storage: storage))
                continue
            }

            if result == SQLITE_DONE {
                break
            }

            throw SQLiteError.execute(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }

        return rows
    }

    private func prepareStatement(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(handle, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError.prepare(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }

        guard let statement else {
            throw SQLiteError.prepare(sql: sql, message: "Prepared statement is nil")
        }

        return statement
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer, sql: String) throws {
        for (index, binding) in bindings.enumerated() {
            let sqliteIndex = Int32(index + 1)
            let result: Int32

            switch binding {
            case .integer(let value):
                result = sqlite3_bind_int64(statement, sqliteIndex, value)
            case .double(let value):
                result = sqlite3_bind_double(statement, sqliteIndex, value)
            case .text(let value):
                result = sqlite3_bind_text(statement, sqliteIndex, value, -1, sqliteTransientDestructor)
            case .null:
                result = sqlite3_bind_null(statement, sqliteIndex)
            }

            if result != SQLITE_OK {
                throw SQLiteError.bind(
                    sql: sql,
                    index: sqliteIndex,
                    message: String(cString: sqlite3_errmsg(handle))
                )
            }
        }
    }

    private func value(at index: Int32, in statement: OpaquePointer) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            return .text(String(cString: sqlite3_column_text(statement, index)))
        default:
            return .null
        }
    }
}

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
