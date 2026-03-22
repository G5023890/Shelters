import Foundation
import OSLog

struct ReportUploadPayload: Sendable {
    let localReportID: UUID
    let canonicalPlaceID: UUID?
    let reportType: ReportType
    let datasetVersion: String
    let textNote: String?
    let userCoordinate: GeoCoordinate?
    let suggestedEntranceCoordinate: GeoCoordinate?
    let localCreatedAt: Date
}

struct PhotoEvidenceUploadPayload: Sendable {
    let localPhotoID: UUID
    let localReportID: UUID
    let localFilePath: String
    let checksum: String?
    let exifCoordinate: GeoCoordinate?
    let capturedAt: Date?
    let hasMetadata: Bool
}

struct UploadedReportReceipt: Sendable {
    let remoteReportID: String?
}

struct ReportingUploadRunResult: Sendable {
    let processedReportIDs: [UUID]
    let succeededReportIDs: [UUID]
    let failedReportIDs: [UUID]

    static let empty = ReportingUploadRunResult(
        processedReportIDs: [],
        succeededReportIDs: [],
        failedReportIDs: []
    )
}

protocol ReportUploadTransport: Sendable {
    func uploadReport(_ payload: ReportUploadPayload) async throws -> UploadedReportReceipt
    func uploadPhotoEvidence(
        _ payload: PhotoEvidenceUploadPayload,
        reportReceipt: UploadedReportReceipt
    ) async throws
}

enum ReportingUploadError: LocalizedError {
    case transportUnavailable
    case networkUnavailable
    case reportNotFound
    case photoEvidenceNotFound
    case invalidReportState
    case invalidRequestBody
    case unsupportedResponse
    case invalidResponseStatus(Int)
    case responseDecodingFailed

    var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            return L10n.string(.reportingUploadErrorTransportUnavailable)
        case .networkUnavailable:
            return L10n.string(.reportingUploadErrorNetworkUnavailable)
        case .reportNotFound:
            return L10n.string(.reportingUploadErrorReportNotFound)
        case .photoEvidenceNotFound:
            return L10n.string(.reportingUploadErrorPhotoNotFound)
        case .invalidReportState:
            return L10n.string(.reportingUploadErrorInvalidState)
        case .invalidRequestBody:
            return L10n.string(.reportingUploadErrorInvalidRequestBody)
        case .unsupportedResponse:
            return L10n.string(.reportingUploadErrorUnsupportedResponse)
        case .invalidResponseStatus(let statusCode):
            return L10n.formatted(.reportingUploadErrorInvalidResponseStatusFormat, statusCode)
        case .responseDecodingFailed:
            return L10n.string(.reportingUploadErrorResponseDecodingFailed)
        }
    }
}

struct UnavailableReportUploadTransport: ReportUploadTransport {
    func uploadReport(_ payload: ReportUploadPayload) async throws -> UploadedReportReceipt {
        throw ReportingUploadError.transportUnavailable
    }

    func uploadPhotoEvidence(
        _ payload: PhotoEvidenceUploadPayload,
        reportReceipt: UploadedReportReceipt
    ) async throws {
        throw ReportingUploadError.transportUnavailable
    }
}

struct URLSessionReportUploadTransport: ReportUploadTransport {
    private static let logger = Logger(subsystem: "com.grigorymordokhovich.Shelters", category: "ReportingUpload")

    let configuration: ReportingAPIConfiguration
    var session: URLSession = .shared

    func uploadReport(_ payload: ReportUploadPayload) async throws -> UploadedReportReceipt {
        let requestBody = ReportUploadRequestDTO(payload: payload)
        let data = try encode(requestBody)
        let request = makeRequest(url: configuration.reportsURL, body: data)
        let (responseData, response) = try await performRequest(request)

        try validate(response: response)

        guard !responseData.isEmpty else {
            return UploadedReportReceipt(remoteReportID: nil)
        }

        do {
            let responseDTO = try ReportingTransportCoding.decoder()
                .decode(ReportUploadResponseDTO.self, from: responseData)
            return UploadedReportReceipt(remoteReportID: responseDTO.remoteReportID)
        } catch {
            throw ReportingUploadError.responseDecodingFailed
        }
    }

    func uploadPhotoEvidence(
        _ payload: PhotoEvidenceUploadPayload,
        reportReceipt: UploadedReportReceipt
    ) async throws {
        let requestBody = PhotoEvidenceUploadRequestDTO(
            payload: payload,
            reportReceipt: reportReceipt
        )
        let data = try encode(requestBody)
        let request = makeRequest(url: configuration.reportPhotosURL, body: data)
        let (_, response) = try await performRequest(request)

        try validate(response: response)
    }

    private func makeRequest(url: URL, body: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = body
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            Self.logger.error("Reporting request failed for \(request.url?.absoluteString ?? "unknown"): \(error.localizedDescription)")
            throw ReportingUploadError.networkUnavailable
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try ReportingTransportCoding.encoder().encode(value)
        } catch {
            throw ReportingUploadError.invalidRequestBody
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportingUploadError.unsupportedResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            Self.logger.error("Reporting request returned status \(httpResponse.statusCode)")
            throw ReportingUploadError.invalidResponseStatus(httpResponse.statusCode)
        }
    }
}
