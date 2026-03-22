import Foundation

enum AppEnvironment: String, CaseIterable, Codable, Sendable {
    case local
    case development
    case production

    static func resolve(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        resolve(environment: processInfo.environment)
    }

    static func resolve(environment: [String: String]) -> AppEnvironment {
        guard
            let rawValue = environment[EnvironmentKeys.appEnvironment],
            let environment = AppEnvironment(rawValue: rawValue.lowercased())
        else {
            return .local
        }

        return environment
    }
}

struct DatasetPublicationConfiguration: Hashable, Codable, Sendable {
    enum SourceKind: String, Codable, Sendable {
        case localHTTP
        case customMetadataURL
        case githubReleases
        case netlifyStatic
    }

    let sourceKind: SourceKind
    let metadataURL: URL
}

struct ReportingAPIConfiguration: Hashable, Codable, Sendable {
    enum SourceKind: String, Codable, Sendable {
        case netlifyFunctions
        case customHTTP
    }

    let sourceKind: SourceKind
    let reportsURL: URL
    let reportPhotosURL: URL
}

struct AppEnvironmentConfiguration: Hashable, Codable, Sendable {
    let environment: AppEnvironment
    let datasetPublication: DatasetPublicationConfiguration?
    let reportingAPI: ReportingAPIConfiguration?

    static func resolve(processInfo: ProcessInfo = .processInfo) -> AppEnvironmentConfiguration {
        resolve(environment: processInfo.environment)
    }

    static func resolve(environment: [String: String]) -> AppEnvironmentConfiguration {
        let resolvedEnvironment = AppEnvironment.resolve(environment: environment)

        return AppEnvironmentConfiguration(
            environment: resolvedEnvironment,
            datasetPublication: resolveDatasetPublication(
                environment: resolvedEnvironment,
                environmentValues: environment
            ),
            reportingAPI: resolveReportingAPI(environmentValues: environment)
        )
    }

    private static func resolveDatasetPublication(
        environment: AppEnvironment,
        environmentValues: [String: String]
    ) -> DatasetPublicationConfiguration? {
        if let metadataURL = url(
            for: EnvironmentKeys.datasetMetadataURL,
            environmentValues: environmentValues
        ) {
            return DatasetPublicationConfiguration(
                sourceKind: inferDatasetSourceKind(from: metadataURL),
                metadataURL: metadataURL
            )
        }

        guard environment == .local else {
            return nil
        }

        return DatasetPublicationConfiguration(
            sourceKind: .localHTTP,
            metadataURL: DatasetPublicationContract.localDevelopmentMetadataURL
        )
    }

    private static func resolveReportingAPI(
        environmentValues: [String: String]
    ) -> ReportingAPIConfiguration? {
        if
            let reportsURL = url(for: EnvironmentKeys.reportsURL, environmentValues: environmentValues),
            let reportPhotosURL = url(for: EnvironmentKeys.reportPhotosURL, environmentValues: environmentValues)
        {
            return ReportingAPIConfiguration(
                sourceKind: .customHTTP,
                reportsURL: reportsURL,
                reportPhotosURL: reportPhotosURL
            )
        }

        if let baseURL = url(for: EnvironmentKeys.netlifyFunctionsBaseURL, environmentValues: environmentValues) {
            return ReportingAPIConfiguration(
                sourceKind: .netlifyFunctions,
                reportsURL: baseURL.appending(path: ReportingPublicationContract.reportsPath),
                reportPhotosURL: baseURL.appending(path: ReportingPublicationContract.reportPhotosPath)
            )
        }

        return nil
    }

    private static func inferDatasetSourceKind(from metadataURL: URL) -> DatasetPublicationConfiguration.SourceKind {
        let host = metadataURL.host()?.lowercased() ?? ""

        if host.contains("github.com") || host.contains("githubusercontent.com") || host.contains("objects.githubusercontent.com") {
            return .githubReleases
        }

        if host.contains("netlify.app") {
            return .netlifyStatic
        }

        if host == "127.0.0.1" || host == "localhost" {
            return .localHTTP
        }

        return .customMetadataURL
    }

    private static func url(for key: String, environmentValues: [String: String]) -> URL? {
        guard let value = environmentValues[key], !value.isEmpty else {
            return nil
        }

        return URL(string: value)
    }
}

private enum EnvironmentKeys {
    static let appEnvironment = "SHELTERS_APP_ENVIRONMENT"
    static let datasetMetadataURL = "SHELTERS_DATASET_METADATA_URL"
    static let netlifyFunctionsBaseURL = "SHELTERS_NETLIFY_FUNCTIONS_BASE_URL"
    static let reportsURL = "SHELTERS_REPORTS_URL"
    static let reportPhotosURL = "SHELTERS_REPORT_PHOTOS_URL"
}
