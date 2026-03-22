import Foundation
import XCTest
@testable import SheltersKit

final class AppEnvironmentConfigurationTests: XCTestCase {
    func testResolveDefaultsToLocalEnvironmentWithLocalDatasetPublication() {
        let configuration = AppEnvironmentConfiguration.resolve(environment: [:])

        XCTAssertEqual(configuration.environment, .local)
        XCTAssertEqual(
            configuration.datasetPublication?.metadataURL,
            DatasetPublicationContract.localDevelopmentMetadataURL
        )
        XCTAssertNil(configuration.reportingAPI)
    }

    func testResolveUsesExplicitMetadataAndNetlifyFunctionsEndpoints() {
        let configuration = AppEnvironmentConfiguration.resolve(
            environment: [
                "SHELTERS_APP_ENVIRONMENT": "production",
                "SHELTERS_DATASET_METADATA_URL": "https://example.netlify.app/dataset-metadata.json",
                "SHELTERS_NETLIFY_FUNCTIONS_BASE_URL": "https://example.netlify.app/.netlify/functions"
            ]
        )

        XCTAssertEqual(configuration.environment, .production)
        XCTAssertEqual(configuration.datasetPublication?.sourceKind, .netlifyStatic)
        XCTAssertEqual(
            configuration.datasetPublication?.metadataURL.absoluteString,
            "https://example.netlify.app/dataset-metadata.json"
        )
        XCTAssertEqual(configuration.reportingAPI?.sourceKind, .netlifyFunctions)
        XCTAssertEqual(
            configuration.reportingAPI?.reportsURL.absoluteString,
            "https://example.netlify.app/.netlify/functions/reports"
        )
        XCTAssertEqual(
            configuration.reportingAPI?.reportPhotosURL.absoluteString,
            "https://example.netlify.app/.netlify/functions/reports/photo"
        )
    }

    func testResolveSupportsCustomReportingEndpointsForDevelopment() {
        let configuration = AppEnvironmentConfiguration.resolve(
            environment: [
                "SHELTERS_APP_ENVIRONMENT": "development",
                "SHELTERS_DATASET_METADATA_URL": "https://objects.githubusercontent.com/assets/dataset-metadata.json",
                "SHELTERS_REPORTS_URL": "https://api.example.com/reports",
                "SHELTERS_REPORT_PHOTOS_URL": "https://api.example.com/reports/photo"
            ]
        )

        XCTAssertEqual(configuration.environment, .development)
        XCTAssertEqual(configuration.datasetPublication?.sourceKind, .githubReleases)
        XCTAssertEqual(configuration.reportingAPI?.sourceKind, .customHTTP)
        XCTAssertEqual(
            configuration.reportingAPI?.reportsURL.absoluteString,
            "https://api.example.com/reports"
        )
        XCTAssertEqual(
            configuration.reportingAPI?.reportPhotosURL.absoluteString,
            "https://api.example.com/reports/photo"
        )
    }
}
