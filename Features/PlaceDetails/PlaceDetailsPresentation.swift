import Foundation

struct PlaceDetailsPresentation: Equatable {
    enum VerificationLevel: Equatable {
        case high
        case good
        case moderate
        case low

        var localizationKey: L10n.Key {
            switch self {
            case .high:
                return .placeDetailsVerificationHigh
            case .good:
                return .placeDetailsVerificationGood
            case .moderate:
                return .placeDetailsVerificationModerate
            case .low:
                return .placeDetailsVerificationLow
            }
        }
    }

    enum RoutingQualityLevel: Equatable {
        case strong
        case usable
        case limited

        var localizationKey: L10n.Key {
            switch self {
            case .strong:
                return .placeDetailsRoutingQualityStrong
            case .usable:
                return .placeDetailsRoutingQualityUsable
            case .limited:
                return .placeDetailsRoutingQualityLimited
            }
        }
    }

    let title: String
    let placeTypeText: String
    let addressText: String?
    let cityText: String?
    let distanceText: String?
    let verificationText: String
    let verificationLevel: VerificationLevel
    let statusText: String
    let entranceAvailabilityText: String
    let routingQualityText: String
    let routingPointSummaryText: String
    let routeCoordinateText: String
    let sourceCoverageText: String?
    let lastVerifiedText: String?
    let installedDatasetVersionText: String?
    let lastSyncText: String?
}

enum PlaceDetailsPresentationBuilder {
    static func make(
        place: CanonicalPlace,
        language: AppLanguage,
        distanceMeters: Double?,
        syncStatus: SyncStatusSnapshot?,
        sourceAttributions: [PlaceSourceAttribution],
        routingTarget: ResolvedRoutingTarget?
    ) -> PlaceDetailsPresentation {
        let verificationLevel = verificationLevel(for: place)
        let routeTarget = routingTarget ?? place.fallbackRoutingTarget
        let distinctSources = Set(sourceAttributions.map(\.sourceName))

        return PlaceDetailsPresentation(
            title: place.displayName(for: language),
            placeTypeText: L10n.string(place.placeType.localizationKey, language: language),
            addressText: nonEmpty(place.displayAddress(for: language)),
            cityText: nonEmpty(place.city),
            distanceText: distanceMeters.map { L10n.formatDistance($0, language: language) },
            verificationText: L10n.string(verificationLevel.localizationKey, language: language),
            verificationLevel: verificationLevel,
            statusText: L10n.string(place.status.localizationKey, language: language),
            entranceAvailabilityText: place.entranceCoordinate == nil
                ? L10n.string(.placeDetailsEntranceUnavailable, language: language)
                : L10n.string(.placeDetailsEntranceAvailable, language: language),
            routingQualityText: L10n.string(routingQualityLevel(for: place).localizationKey, language: language),
            routingPointSummaryText: L10n.string(routeTarget.source.localizationKey, language: language),
            routeCoordinateText: routeTarget.coordinate.formattedString(),
            sourceCoverageText: sourceAttributions.isEmpty
                ? nil
                : L10n.formatted(
                    .placeDetailsSourceCoverageFormat,
                    language: language,
                    sourceAttributions.count,
                    distinctSources.count
                ),
            lastVerifiedText: place.lastVerifiedAt.map(formatDate),
            installedDatasetVersionText: nonEmpty(syncStatus?.installedDatasetVersion),
            lastSyncText: syncStatus?.lastSuccessfulSyncAt.map(formatDate)
        )
    }

    private static func verificationLevel(for place: CanonicalPlace) -> PlaceDetailsPresentation.VerificationLevel {
        if place.status == .unverified {
            return .low
        }

        switch place.confidenceScore {
        case 0.9...:
            return .high
        case 0.75...:
            return .good
        case 0.6...:
            return .moderate
        default:
            return .low
        }
    }

    private static func routingQualityLevel(for place: CanonicalPlace) -> PlaceDetailsPresentation.RoutingQualityLevel {
        switch place.routingQuality {
        case 0.8...:
            return .strong
        case 0.6...:
            return .usable
        default:
            return .limited
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted))
    }
}
