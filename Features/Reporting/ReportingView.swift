import SwiftUI

struct ReportingView: View {
    private let reportingService: ReportingService
    private let locationService: LocationService
    private let syncService: SyncService
    private let diagnostics: AppEnvironmentDiagnostics

    @StateObject private var viewModel: ReportingViewModel
    @State private var createReportType: ReportType?

    init(
        reportingService: ReportingService,
        locationService: LocationService,
        syncService: SyncService,
        diagnostics: AppEnvironmentDiagnostics
    ) {
        self.reportingService = reportingService
        self.locationService = locationService
        self.syncService = syncService
        self.diagnostics = diagnostics
        self._viewModel = StateObject(wrappedValue: ReportingViewModel(reportingService: reportingService))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.text(.reportingSubtitle))
                        .foregroundStyle(.secondary)

                    MetadataRow(
                        title: L10n.string(.reportingBackendStatus),
                        value: diagnostics.isReportingConfigured
                            ? L10n.string(.reportingBackendConfigured)
                            : L10n.string(.reportingBackendUnavailable)
                    )

                    if let reportsURL = diagnostics.reportsURL {
                        MetadataRow(
                            title: L10n.string(.reportingBackendReportsEndpoint),
                            value: reportsURL.absoluteString
                        )
                    }

                    Button {
                        Task {
                            await viewModel.processUploads()
                        }
                    } label: {
                        if viewModel.isProcessingUploads {
                            ProgressView()
                        } else {
                            Text(L10n.text(.reportingUploadNow))
                        }
                    }

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(L10n.string(.reportingTypesSection)) {
                    ForEach(ReportType.allCases) { reportType in
                        Button {
                            createReportType = reportType
                        } label: {
                            HStack(spacing: 12) {
                                Label(
                                    title: {
                                        Text(L10n.text(reportType.localizationKey))
                                    },
                                    icon: {
                                        Image(systemName: reportType.systemImageName)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                )
                                Spacer()
                                Text(L10n.text(.commonCreate))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(L10n.string(.reportingPendingSection)) {
                    if viewModel.pendingReports.isEmpty {
                        Text(L10n.text(.reportingNoPending))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.pendingReports) { report in
                            NavigationLink {
                                ReportDetailView(
                                    report: report,
                                    reportingService: reportingService,
                                    onChanged: {
                                        await viewModel.load()
                                    }
                                )
                            } label: {
                                ReportSummaryRow(report: report)
                            }
                        }
                    }
                }

                Section(L10n.string(.reportingHistorySection)) {
                    if viewModel.reportHistory.isEmpty {
                        Text(L10n.text(.reportingNoHistory))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.reportHistory) { report in
                            NavigationLink {
                                ReportDetailView(
                                    report: report,
                                    reportingService: reportingService,
                                    onChanged: {
                                        await viewModel.load()
                                    }
                                )
                            } label: {
                                ReportSummaryRow(report: report)
                            }
                        }
                    }
                }

                Section(L10n.string(.reportingUploadQueueSection)) {
                    if viewModel.pendingUploads.isEmpty {
                        Text(L10n.text(.reportingUploadQueueEmpty))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.pendingUploads) { item in
                            PendingUploadRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle(L10n.string(.reportingTitle))
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $createReportType) { reportType in
                CreateReportView(
                    initialReportType: reportType,
                    reportingService: reportingService,
                    locationService: locationService,
                    syncService: syncService,
                    onCreated: { _ in
                        await viewModel.load()
                    }
                )
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
    }
}
