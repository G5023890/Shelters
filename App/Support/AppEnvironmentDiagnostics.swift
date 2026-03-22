import Foundation

struct AppEnvironmentDiagnostics: Equatable, Sendable {
    let environmentName: String
    let datasetSourceName: String
    let metadataURL: URL?
    let reportingSourceName: String
    let reportsURL: URL?
    let reportPhotosURL: URL?
    let isReportingConfigured: Bool
}

extension AppEnvironmentConfiguration {
    var diagnostics: AppEnvironmentDiagnostics {
        AppEnvironmentDiagnostics(
            environmentName: environment.rawValue,
            datasetSourceName: datasetPublication?.sourceKind.rawValue ?? "unconfigured",
            metadataURL: datasetPublication?.metadataURL,
            reportingSourceName: reportingAPI?.sourceKind.rawValue ?? "unconfigured",
            reportsURL: reportingAPI?.reportsURL,
            reportPhotosURL: reportingAPI?.reportPhotosURL,
            isReportingConfigured: reportingAPI != nil
        )
    }
}
