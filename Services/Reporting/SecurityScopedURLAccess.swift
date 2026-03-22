import Foundation

extension URL {
    func withSecurityScopedAccess<T>(_ operation: () throws -> T) throws -> T {
        let didAccess = startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                stopAccessingSecurityScopedResource()
            }
        }

        return try operation()
    }
}
