import Foundation

struct AtomicDatabaseReplacementPlan: Hashable, Codable, Sendable {
    let datasetVersion: String
    let liveDatabaseURL: URL
    let stagedDatabaseURL: URL
    let backupDatabaseURL: URL
    let createdAt: Date
}

protocol AtomicDatabaseReplacing: Sendable {
    func stageReplacementCandidate(
        downloadedFileURL: URL,
        liveDatabaseURL: URL,
        datasetVersion: String
    ) throws -> AtomicDatabaseReplacementPlan

    func replaceDatabase(using plan: AtomicDatabaseReplacementPlan) throws
}

enum AtomicDatabaseReplacementError: LocalizedError {
    case failedToStageCandidate
    case failedToBackupLiveDatabase
    case failedToReplaceDatabase
    case failedToRestoreBackup

    var errorDescription: String? {
        switch self {
        case .failedToStageCandidate:
            return "Downloaded dataset could not be staged for atomic replacement."
        case .failedToBackupLiveDatabase:
            return "Current local database could not be backed up before replacement."
        case .failedToReplaceDatabase:
            return "Prepared dataset could not replace the current local database."
        case .failedToRestoreBackup:
            return "The previous local database could not be restored after replacement failure."
        }
    }
}

struct SQLiteAtomicDatabaseReplacer: AtomicDatabaseReplacing {
    func stageReplacementCandidate(
        downloadedFileURL: URL,
        liveDatabaseURL: URL,
        datasetVersion: String
    ) throws -> AtomicDatabaseReplacementPlan {
        let fileManager = FileManager.default
        let stagingDirectory = liveDatabaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("SyncStaging", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        let sanitizedVersion = datasetVersion
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9._-]", with: "-", options: .regularExpression)
        let stagedDatabaseURL = stagingDirectory.appendingPathComponent("shelters-\(sanitizedVersion).sqlite")
        let backupDatabaseURL = stagingDirectory.appendingPathComponent(
            "backup-\(DateCoding.string(from: Date()).replacingOccurrences(of: ":", with: "-")).sqlite"
        )

        do {
            if fileManager.fileExists(atPath: stagedDatabaseURL.path) {
                try fileManager.removeItem(at: stagedDatabaseURL)
            }

            try fileManager.copyItem(at: downloadedFileURL, to: stagedDatabaseURL)
        } catch {
            throw AtomicDatabaseReplacementError.failedToStageCandidate
        }

        return AtomicDatabaseReplacementPlan(
            datasetVersion: datasetVersion,
            liveDatabaseURL: liveDatabaseURL,
            stagedDatabaseURL: stagedDatabaseURL,
            backupDatabaseURL: backupDatabaseURL,
            createdAt: Date()
        )
    }

    func replaceDatabase(using plan: AtomicDatabaseReplacementPlan) throws {
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: plan.liveDatabaseURL.path) {
                if fileManager.fileExists(atPath: plan.backupDatabaseURL.path) {
                    try fileManager.removeItem(at: plan.backupDatabaseURL)
                }

                try removeSQLiteSidecars(for: plan.liveDatabaseURL, fileManager: fileManager)
                try fileManager.moveItem(at: plan.liveDatabaseURL, to: plan.backupDatabaseURL)
            }
        } catch {
            throw AtomicDatabaseReplacementError.failedToBackupLiveDatabase
        }

        do {
            if fileManager.fileExists(atPath: plan.liveDatabaseURL.path) {
                try fileManager.removeItem(at: plan.liveDatabaseURL)
            }

            try fileManager.moveItem(at: plan.stagedDatabaseURL, to: plan.liveDatabaseURL)
        } catch {
            do {
                if fileManager.fileExists(atPath: plan.liveDatabaseURL.path) {
                    try fileManager.removeItem(at: plan.liveDatabaseURL)
                }

                if fileManager.fileExists(atPath: plan.backupDatabaseURL.path) {
                    try fileManager.moveItem(at: plan.backupDatabaseURL, to: plan.liveDatabaseURL)
                }

                if fileManager.fileExists(atPath: plan.stagedDatabaseURL.path) {
                    try? fileManager.removeItem(at: plan.stagedDatabaseURL)
                }
            } catch {
                throw AtomicDatabaseReplacementError.failedToRestoreBackup
            }

            throw AtomicDatabaseReplacementError.failedToReplaceDatabase
        }
    }

    private func removeSQLiteSidecars(for databaseURL: URL, fileManager: FileManager) throws {
        let walURL = databaseURL.appendingPathExtension("wal")
        let shmURL = databaseURL.appendingPathExtension("shm")

        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }

        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
    }
}
