import SwiftUI
import UniformTypeIdentifiers

struct ReportDetailView: View {
    let report: UserReport

    @StateObject private var viewModel: ReportDetailViewModel
    @State private var isImportingPhoto = false

    private let onChanged: @MainActor () async -> Void

    init(
        report: UserReport,
        reportingService: ReportingService,
        onChanged: @escaping @MainActor () async -> Void
    ) {
        self.report = report
        self._viewModel = StateObject(
            wrappedValue: ReportDetailViewModel(
                report: report,
                reportingService: reportingService
            )
        )
        self.onChanged = onChanged
    }

    var body: some View {
        let currentReport = viewModel.currentReport ?? report

        List {
            Section(L10n.string(.reportingDetailTitle)) {
                MetadataRow(
                    title: L10n.string(.reportingStatus),
                    value: L10n.string(currentReport.reportStatus.localizationKey)
                )
                MetadataRow(
                    title: L10n.string(.reportingCreatedAt),
                    value: DateCoding.string(from: currentReport.localCreatedAt)
                )
                MetadataRow(
                    title: L10n.string(.reportingDatasetVersion),
                    value: currentReport.displayDatasetVersion ?? L10n.string(.settingsNotAvailable)
                )
                MetadataRow(
                    title: L10n.string(.reportingStatusUpdatedAt),
                    value: DateCoding.string(from: currentReport.statusUpdatedAt)
                )
                MetadataRow(
                    title: L10n.string(.reportingUploadAttempts),
                    value: String(currentReport.uploadAttemptCount)
                )
                MetadataRow(
                    title: L10n.string(.reportingLastUploadAttempt),
                    value: currentReport.lastUploadAttemptAt.map(DateCoding.string) ?? L10n.string(.settingsNotAvailable)
                )
                MetadataRow(
                    title: L10n.string(.reportingLastError),
                    value: currentReport.lastError ?? L10n.string(.settingsNotAvailable)
                )
                MetadataRow(
                    title: L10n.string(.reportingUserCoordinates),
                    value: currentReport.userCoordinate?.formattedString() ?? L10n.string(.reportingNoLocation)
                )
                MetadataRow(
                    title: L10n.string(.reportingSuggestedEntrance),
                    value: currentReport.suggestedEntranceCoordinate?.formattedString() ?? L10n.string(.reportingNoLocation)
                )
            }

            Section(L10n.string(.reportingNote)) {
                Text(currentReport.textNote ?? L10n.string(.reportingNoNote))
                    .foregroundStyle(currentReport.textNote == nil ? .secondary : .primary)
            }

            Section(L10n.string(.reportingUploadQueueSection)) {
                if currentReport.reportStatus == .failed || currentReport.reportStatus == .pendingUpload {
                    Button(L10n.text(.reportingRetryUpload)) {
                        Task {
                            await viewModel.retryUpload()
                            await onChanged()
                        }
                    }
                }

                if currentReport.reportStatus == .pendingUpload || currentReport.reportStatus == .uploading {
                    Button(L10n.text(.reportingUploadNow)) {
                        Task {
                            await viewModel.processUploads()
                            await onChanged()
                        }
                    }
                }

                if viewModel.isProcessingUploads {
                    ProgressView()
                }
            }

            Section(L10n.string(.reportingPhotosSection)) {
                Button(L10n.text(.reportingAttachPhoto)) {
                    isImportingPhoto = true
                }

                if viewModel.isAttachingPhoto {
                    ProgressView()
                }

                if viewModel.photos.isEmpty {
                    Text(L10n.text(.reportingNoPhotos))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.photos) { photo in
                        PhotoEvidenceRow(photo: photo)
                    }
                }
            }

            Section(L10n.string(.reportingUploadQueueSection)) {
                if viewModel.relatedPendingUploads.isEmpty {
                    Text(L10n.text(.reportingUploadQueueEmpty))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.relatedPendingUploads) { item in
                        PendingUploadRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(L10n.string(.reportingDetailTitle))
        .task {
            await viewModel.load()
        }
        .fileImporter(
            isPresented: $isImportingPhoto,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleImport(result)
            }
        }
        .alert(
            L10n.string(.commonClose),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            ),
            actions: {
                Button(L10n.text(.commonDone), role: .cancel) {
                    viewModel.errorMessage = nil
                }
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        do {
            guard let selectedURL = try result.get().first else {
                return
            }

            await viewModel.attachPhoto(from: selectedURL)
            await onChanged()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ReportDetailViewModel: ObservableObject {
    @Published private(set) var currentReport: UserReport?
    @Published private(set) var photos: [PhotoEvidence] = []
    @Published private(set) var pendingUploads: [PendingUploadItem] = []
    @Published private(set) var isAttachingPhoto = false
    @Published private(set) var isProcessingUploads = false
    @Published var errorMessage: String?

    let report: UserReport

    private let reportingService: ReportingService

    init(
        report: UserReport,
        reportingService: ReportingService
    ) {
        self.report = report
        self.reportingService = reportingService
    }

    var relatedPendingUploads: [PendingUploadItem] {
        let photoIDs = Set(photos.map { $0.id.uuidString })

        return pendingUploads.filter { item in
            switch item.entityType {
            case .userReport:
                return item.entityID == report.id.uuidString
            case .photoEvidence:
                return photoIDs.contains(item.entityID)
            }
        }
    }

    func load() async {
        do {
            async let loadedReport = reportingService.fetchReport(id: report.id)
            async let loadedPhotos = reportingService.fetchPhotoEvidence(for: report.id)
            async let loadedUploads = reportingService.fetchUploads(for: report.id)

            currentReport = try await loadedReport
            photos = try await loadedPhotos
            pendingUploads = try await loadedUploads
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachPhoto(from fileURL: URL) async {
        isAttachingPhoto = true
        defer { isAttachingPhoto = false }

        do {
            let draft = try await reportingService.preparePhotoDraft(from: fileURL)
            _ = try await reportingService.attachPreparedPhoto(draft, to: report.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryUpload() async {
        isProcessingUploads = true
        defer { isProcessingUploads = false }

        do {
            _ = try await reportingService.retryUpload(for: report.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func processUploads() async {
        isProcessingUploads = true
        defer { isProcessingUploads = false }

        do {
            _ = try await reportingService.processPendingUploads()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
