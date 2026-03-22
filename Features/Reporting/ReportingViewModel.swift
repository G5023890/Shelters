import Foundation

@MainActor
final class ReportingViewModel: ObservableObject {
    @Published private(set) var reports: [UserReport] = []
    @Published private(set) var pendingUploads: [PendingUploadItem] = []
    @Published private(set) var isProcessingUploads = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let reportingService: ReportingService

    init(reportingService: ReportingService) {
        self.reportingService = reportingService
    }

    func load() async {
        do {
            async let reports = reportingService.fetchAllReports(limit: 50)
            async let uploads = reportingService.fetchPendingUploads()

            self.reports = try await reports
            pendingUploads = try await uploads
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var pendingReports: [UserReport] {
        reports.filter(\.isActiveForUpload)
    }

    var reportHistory: [UserReport] {
        reports.filter { !$0.isActiveForUpload }
    }

    func processUploads() async {
        isProcessingUploads = true
        defer { isProcessingUploads = false }

        do {
            let result = try await reportingService.processPendingUploads()
            statusMessage = L10n.formatted(
                .reportingUploadSummaryFormat,
                result.succeededReportIDs.count,
                result.failedReportIDs.count
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
