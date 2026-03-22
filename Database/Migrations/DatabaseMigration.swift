import Foundation

struct DatabaseMigration {
    let version: Int
    let name: String
    let statements: [String]
}

