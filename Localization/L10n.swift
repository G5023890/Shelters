import Foundation
import SwiftUI

enum L10n {
    enum Key: String {
        case appTitle = "app.title"
        case bootstrapLoading = "bootstrap.loading"
        case bootstrapFailedTitle = "bootstrap.failed.title"
        case commonRetry = "common.retry"
        case commonSave = "common.save"
        case commonCreate = "common.create"
        case commonAdd = "common.add"
        case commonDone = "common.done"
        case commonClear = "common.clear"
        case commonCancel = "common.cancel"
        case commonClose = "common.close"
        case commonComingSoon = "common.comingSoon"
        case commonPreferred = "common.preferred"
        case commonYes = "common.yes"
        case commonNo = "common.no"
        case nearbyTitle = "nearby.title"
        case nearbySubtitle = "nearby.subtitle"
        case nearbyEmptyTitle = "nearby.empty.title"
        case nearbyEmptyMessage = "nearby.empty.message"
        case nearbyNoLocation = "nearby.noLocation"
        case nearbyDistanceFormat = "nearby.distance.format"
        case nearbyDistanceKilometersFormat = "nearby.distance.kilometers.format"
        case nearbyWalkingMinutesFormat = "nearby.walkingMinutes.format"
        case nearbyResultsSection = "nearby.results.section"
        case nearbyRecentSection = "nearby.recent.section"
        case nearbyUseMyLocation = "nearby.useMyLocation"
        case nearbyRefresh = "nearby.refresh"
        case nearbyLocationPermissionPrompt = "nearby.location.permissionPrompt"
        case nearbyLocationDenied = "nearby.location.denied"
        case nearbyLocationUnavailable = "nearby.location.unavailable"
        case nearbyEmergencyCutoffMessage = "nearby.emergencyCutoff.message"
        case mapPreviewTitle = "mapPreview.title"
        case mapPreviewSearchPrompt = "mapPreview.searchPrompt"
        case mapPreviewPlacesSection = "mapPreview.places.section"
        case mapPreviewNearestRoutesSection = "mapPreview.nearestRoutes.section"
        case mapPreviewRoutingPointsSection = "mapPreview.routingPoints.section"
        case mapPreviewEmptyTitle = "mapPreview.empty.title"
        case mapPreviewEmptyMessage = "mapPreview.empty.message"
        case mapPreviewNoSelection = "mapPreview.noSelection"
        case mapPreviewUseMyLocation = "mapPreview.useMyLocation"
        case mapPreviewPickLocation = "mapPreview.pickLocation"
        case mapPreviewCancelPickLocation = "mapPreview.cancelPickLocation"
        case mapPreviewClearPickedLocation = "mapPreview.clearPickedLocation"
        case mapPreviewUseMapCenter = "mapPreview.useMapCenter"
        case mapPreviewPickLocationHint = "mapPreview.pickLocationHint"
        case mapPreviewPickedLocation = "mapPreview.pickedLocation"
        case mapPreviewManualLocationBadge = "mapPreview.manualLocationBadge"
        case mapPreviewRefresh = "mapPreview.refresh"
        case mapPreviewCurrentLocation = "mapPreview.currentLocation"
        case mapPreviewSelectedRoute = "mapPreview.selectedRoute"
        case mapPreviewRouteDistance = "mapPreview.routeDistance"
        case mapPreviewRouteTravelTime = "mapPreview.routeTravelTime"
        case mapPreviewRouteUnavailable = "mapPreview.routeUnavailable"
        case mapPreviewRouteMode = "mapPreview.routeMode"
        case mapPreviewTransportWalking = "mapPreview.transport.walking"
        case mapPreviewTransportDriving = "mapPreview.transport.driving"
        case mapPreviewPolicyNote = "mapPreview.policyNote"
        case placeDetailsTitle = "placeDetails.title"
        case placeDetailsSummarySection = "placeDetails.summary.section"
        case placeDetailsActionsSection = "placeDetails.actions.section"
        case placeDetailsRoutingSection = "placeDetails.routing.section"
        case placeDetailsVerificationSection = "placeDetails.verification.section"
        case placeDetailsMetadataSection = "placeDetails.metadata.section"
        case placeDetailsCoordinatesSection = "placeDetails.coordinates.section"
        case placeDetailsRoutingPointsSection = "placeDetails.routingPoints.section"
        case placeDetailsReportAction = "placeDetails.reportAction"
        case placeDetailsRoutingSource = "placeDetails.routing.source"
        case placeDetailsRoutingPointType = "placeDetails.routing.pointType"
        case placeDetailsSelectedCoordinates = "placeDetails.routing.selectedCoordinates"
        case placeDetailsPreferredProvider = "placeDetails.routing.preferredProvider"
        case placeDetailsOpenInFormat = "placeDetails.routing.openInFormat"
        case placeDetailsOtherApps = "placeDetails.routing.otherApps"
        case placeDetailsObjectCoordinates = "placeDetails.coordinates.object"
        case placeDetailsEntranceCoordinates = "placeDetails.coordinates.entrance"
        case placeDetailsCity = "placeDetails.city"
        case placeDetailsStatus = "placeDetails.status"
        case placeDetailsVerificationTitle = "placeDetails.verification.title"
        case placeDetailsVerificationHigh = "placeDetails.verification.high"
        case placeDetailsVerificationGood = "placeDetails.verification.good"
        case placeDetailsVerificationModerate = "placeDetails.verification.moderate"
        case placeDetailsVerificationLow = "placeDetails.verification.low"
        case placeDetailsRoutingQualityTitle = "placeDetails.routingQuality.title"
        case placeDetailsRoutingQualityStrong = "placeDetails.routingQuality.strong"
        case placeDetailsRoutingQualityUsable = "placeDetails.routingQuality.usable"
        case placeDetailsRoutingQualityLimited = "placeDetails.routingQuality.limited"
        case placeDetailsEntranceAvailability = "placeDetails.entranceAvailability"
        case placeDetailsEntranceAvailable = "placeDetails.entranceAvailability.available"
        case placeDetailsEntranceUnavailable = "placeDetails.entranceAvailability.unavailable"
        case placeDetailsLastVerifiedAt = "placeDetails.lastVerifiedAt"
        case placeDetailsDatasetVersion = "placeDetails.datasetVersion"
        case placeDetailsLastSyncAt = "placeDetails.lastSyncAt"
        case placeDetailsSourceCoverage = "placeDetails.sourceCoverage"
        case placeDetailsSourceCoverageFormat = "placeDetails.sourceCoverage.format"
        case placeDetailsMissing = "placeDetails.missing"
        case reportingTitle = "reporting.title"
        case reportingSubtitle = "reporting.subtitle"
        case reportingTypesSection = "reporting.types.section"
        case reportingPendingSection = "reporting.pending.section"
        case reportingHistorySection = "reporting.history.section"
        case reportingUploadQueueSection = "reporting.uploadQueue.section"
        case reportingCreateButton = "reporting.create.button"
        case reportingUploadNow = "reporting.uploadNow"
        case reportingRetryUpload = "reporting.retryUpload"
        case reportingUploadSummaryFormat = "reporting.uploadSummary.format"
        case reportingNoPending = "reporting.pending.empty"
        case reportingNoHistory = "reporting.history.empty"
        case reportingUploadQueueEmpty = "reporting.uploadQueue.empty"
        case reportingDetailTitle = "reporting.detail.title"
        case reportingStatus = "reporting.status"
        case reportingCreatedAt = "reporting.createdAt"
        case reportingDatasetVersion = "reporting.datasetVersion"
        case reportingStatusUpdatedAt = "reporting.statusUpdatedAt"
        case reportingLastUploadAttempt = "reporting.lastUploadAttempt"
        case reportingUploadAttempts = "reporting.uploadAttempts"
        case reportingLastError = "reporting.lastError"
        case reportingUserCoordinates = "reporting.userCoordinates"
        case reportingSuggestedEntrance = "reporting.suggestedEntrance"
        case reportingNote = "reporting.note"
        case reportingNoNote = "reporting.note.empty"
        case reportingNoLocation = "reporting.location.empty"
        case reportingFormType = "reporting.form.type"
        case reportingFormCurrentLocation = "reporting.form.currentLocation"
        case reportingFormUseCurrentLocation = "reporting.form.useCurrentLocation"
        case reportingFormClearLocation = "reporting.form.clearLocation"
        case reportingFormUseCurrentLocationForEntrance = "reporting.form.useCurrentLocationForEntrance"
        case reportingFormDatasetVersion = "reporting.form.datasetVersion"
        case reportingFormSave = "reporting.form.save"
        case reportingFormNotePlaceholder = "reporting.form.notePlaceholder"
        case reportingPhotosSection = "reporting.photos.section"
        case reportingAttachPhoto = "reporting.attachPhoto"
        case reportingNoPhotos = "reporting.photos.empty"
        case reportingPhotoFile = "reporting.photo.file"
        case reportingPhotoCapturedAt = "reporting.photo.capturedAt"
        case reportingPhotoCoordinates = "reporting.photo.coordinates"
        case reportingPhotoMetadataMissing = "reporting.photo.metadataMissing"
        case reportingPhotoChecksum = "reporting.photo.checksum"
        case reportingUploadEntityReport = "reporting.upload.entity.report"
        case reportingUploadEntityPhoto = "reporting.upload.entity.photo"
        case reportingUploadStatePendingUpload = "reporting.upload.state.pendingUpload"
        case reportingUploadStateUploading = "reporting.upload.state.uploading"
        case reportingUploadStateFailed = "reporting.upload.state.failed"
        case reportingUploadStateUploaded = "reporting.upload.state.uploaded"
        case reportingUploadErrorTransportUnavailable = "reporting.upload.error.transportUnavailable"
        case reportingUploadErrorReportNotFound = "reporting.upload.error.reportNotFound"
        case reportingUploadErrorPhotoNotFound = "reporting.upload.error.photoNotFound"
        case reportingUploadErrorInvalidState = "reporting.upload.error.invalidState"
        case reportingUploadErrorInvalidRequestBody = "reporting.upload.error.invalidRequestBody"
        case reportingUploadErrorUnsupportedResponse = "reporting.upload.error.unsupportedResponse"
        case reportingUploadErrorInvalidResponseStatusFormat = "reporting.upload.error.invalidResponseStatus.format"
        case reportingUploadErrorResponseDecodingFailed = "reporting.upload.error.responseDecodingFailed"
        case reportingUploadErrorNetworkUnavailable = "reporting.upload.error.networkUnavailable"
        case reportingBackendStatus = "reporting.backend.status"
        case reportingBackendConfigured = "reporting.backend.configured"
        case reportingBackendUnavailable = "reporting.backend.unavailable"
        case reportingBackendReportsEndpoint = "reporting.backend.reportsEndpoint"
        case settingsTitle = "settings.title"
        case settingsLanguageSection = "settings.language.section"
        case settingsRoutingSection = "settings.routing.section"
        case settingsRoutingHint = "settings.routing.hint"
        case settingsSyncSection = "settings.sync.section"
        case settingsEnvironmentSection = "settings.environment.section"
        case settingsEnvironmentName = "settings.environment.name"
        case settingsDatasetSource = "settings.environment.datasetSource"
        case settingsDatasetEndpoint = "settings.environment.datasetEndpoint"
        case settingsReportingSource = "settings.environment.reportingSource"
        case settingsReportsEndpoint = "settings.environment.reportsEndpoint"
        case settingsReportPhotosEndpoint = "settings.environment.reportPhotosEndpoint"
        case settingsPreferredRoutingProvider = "settings.routing.preferred"
        case settingsLanguageOverride = "settings.language.override"
        case settingsLastSync = "settings.sync.last"
        case settingsDatasetVersion = "settings.sync.datasetVersion"
        case settingsNotAvailable = "settings.notAvailable"
        case settingsSystemDefault = "settings.systemDefault"
        case syncStatusTitle = "syncStatus.title"
        case syncStatusDatasetVersion = "syncStatus.datasetVersion"
        case syncStatusInstalledDatasetVersion = "syncStatus.installedDatasetVersion"
        case syncStatusRemoteDatasetVersion = "syncStatus.remoteDatasetVersion"
        case syncStatusLastChecked = "syncStatus.lastChecked"
        case syncStatusLastPrepared = "syncStatus.lastPrepared"
        case syncStatusLastError = "syncStatus.lastError"
        case syncStatusActivityState = "syncStatus.activityState"
        case syncStatusUpdateAvailability = "syncStatus.updateAvailability"
        case syncStatusSyncNow = "syncStatus.syncNow"
        case syncActivityIdle = "syncActivity.idle"
        case syncActivityCheckingRemoteMetadata = "syncActivity.checkingRemoteMetadata"
        case syncActivityRemoteMetadataUnavailable = "syncActivity.remoteMetadataUnavailable"
        case syncActivityUpdateAvailable = "syncActivity.updateAvailable"
        case syncActivityUpToDate = "syncActivity.upToDate"
        case syncActivityDownloadingDataset = "syncActivity.downloadingDataset"
        case syncActivityValidatingChecksum = "syncActivity.validatingChecksum"
        case syncActivityReadyToReplaceDatabase = "syncActivity.readyToReplaceDatabase"
        case syncActivityFailed = "syncActivity.failed"
        case syncAvailabilityUnknown = "syncAvailability.unknown"
        case syncAvailabilityUnavailable = "syncAvailability.unavailable"
        case syncAvailabilityUpToDate = "syncAvailability.upToDate"
        case syncAvailabilityUpdateAvailable = "syncAvailability.updateAvailable"
        case languageEnglish = "language.english"
        case languageRussian = "language.russian"
        case languageHebrew = "language.hebrew"
        case placeTypePublicShelter = "placeType.public_shelter"
        case placeTypeMigunit = "placeType.migunit"
        case placeTypeProtectedParking = "placeType.protected_parking"
        case placeTypeUnderground = "placeType.underground"
        case placeTypeOther = "placeType.other"
        case placeStatusActive = "placeStatus.active"
        case placeStatusInactive = "placeStatus.inactive"
        case placeStatusUnverified = "placeStatus.unverified"
        case placeStatusTemporarilyUnavailable = "placeStatus.temporarily_unavailable"
        case placeStatusRemoved = "placeStatus.removed"
        case routingProviderAppleMaps = "routing.provider.appleMaps"
        case routingProviderGoogleMaps = "routing.provider.googleMaps"
        case routingProviderWaze = "routing.provider.waze"
        case routingPointTypeEntrance = "routingPointType.entrance"
        case routingPointTypePreferred = "routingPointType.preferred"
        case routingPointTypeObject = "routingPointType.object"
        case routingPointTypeInferred = "routingPointType.inferred"
        case routingPointTypeUserSubmitted = "routingPointType.userSubmitted"
        case routingTargetSourcePlaceEntrance = "routingTargetSource.placeEntrance"
        case routingTargetSourceRoutingPoint = "routingTargetSource.routingPoint"
        case routingTargetSourceStoredPreferred = "routingTargetSource.storedPreferred"
        case routingTargetSourceObjectFallback = "routingTargetSource.objectFallback"
        case reportTypeWrongLocation = "reportType.wrongLocation"
        case reportTypeConfirmLocation = "reportType.confirmLocation"
        case reportTypeMovedEntrance = "reportType.movedEntrance"
        case reportTypeNewPlace = "reportType.newPlace"
        case reportTypePhotoEvidence = "reportType.photoEvidence"
        case reportStatusDraft = "reportStatus.draft"
        case reportStatusPendingUpload = "reportStatus.pendingUpload"
        case reportStatusUploading = "reportStatus.uploading"
        case reportStatusUploaded = "reportStatus.uploaded"
        case reportStatusFailed = "reportStatus.failed"
        case metadataConfidenceScore = "metadata.confidenceScore"
        case metadataRoutingQuality = "metadata.routingQuality"
        case metadataAccessibility = "metadata.accessibility"
        case metadataPublicAccess = "metadata.publicAccess"
    }

    static func text(_ key: Key) -> LocalizedStringKey {
        LocalizedStringKey(string(key))
    }

    static func string(_ key: Key) -> String {
        let localized = localizedString(forKey: key.rawValue, bundle: resolvedBundle())
        if localized != key.rawValue {
            return localized
        }

        return sourceTreeString(forKey: key.rawValue, languageCode: AppLanguage.english.localeIdentifier) ?? localized
    }

    static func string(_ key: Key, language: AppLanguage) -> String {
        guard
            let bundlePath = resolvedBundle().path(forResource: language.localeIdentifier, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            return sourceTreeString(forKey: key.rawValue, languageCode: language.localeIdentifier) ?? string(key)
        }

        let localized = localizedString(forKey: key.rawValue, bundle: bundle)
        if localized != key.rawValue {
            return localized
        }

        return sourceTreeString(forKey: key.rawValue, languageCode: language.localeIdentifier) ?? string(key)
    }

    static func formatted(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }

    static func formatted(_ key: Key, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(
            format: string(key, language: language),
            locale: Locale(identifier: language.localeIdentifier),
            arguments: arguments
        )
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            let kilometers = meters / 1000
            return String(format: string(.nearbyDistanceKilometersFormat), kilometers)
        }

        let rounded = Int(meters.rounded())
        return String(format: string(.nearbyDistanceFormat), rounded)
    }

    static func formatDistance(_ meters: Double, language: AppLanguage) -> String {
        if meters >= 1000 {
            let kilometers = meters / 1000
            return String(
                format: string(.nearbyDistanceKilometersFormat, language: language),
                locale: Locale(identifier: language.localeIdentifier),
                kilometers
            )
        }

        let rounded = Int(meters.rounded())
        return String(
            format: string(.nearbyDistanceFormat, language: language),
            locale: Locale(identifier: language.localeIdentifier),
            rounded
        )
    }

    private static func resolvedBundle() -> Bundle {
        let frameworkBundle = Bundle(for: BundleToken.self)
        if frameworkBundle.path(forResource: "en", ofType: "lproj") != nil {
            return frameworkBundle
        }

        return .main
    }

    private static func localizedString(forKey key: String, bundle: Bundle) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    private static func sourceTreeString(forKey key: String, languageCode: String) -> String? {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Localization/\(languageCode).lproj/Localizable.strings")

        guard
            let strings = NSDictionary(contentsOf: sourceURL) as? [String: String],
            let value = strings[key]
        else {
            return nil
        }

        return value
    }
}

private final class BundleToken {}
