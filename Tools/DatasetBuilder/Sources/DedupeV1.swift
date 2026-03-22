import CryptoKit
import Foundation

struct NormalizedSourcePlaceRecord {
    let stableID: String
    let sourceName: String
    let sourceIdentifier: String
    let sourceDisplayName: String
    let city: String
    let normalizedCity: String
    let placeType: String
    let objectLat: Double
    let objectLon: Double
    let entranceLat: Double?
    let entranceLon: Double?
    let routingPoints: [NormalizedSourceRoutingPoint]
    let nameOriginal: String?
    let nameEn: String?
    let nameRu: String?
    let nameHe: String?
    let addressOriginal: String?
    let addressEn: String?
    let addressRu: String?
    let addressHe: String?
    let normalizedName: String?
    let normalizedAddress: String?
    let isPublic: Bool
    let isAccessible: Bool
    let status: String
    let sourceConfidence: Double
    let sourceRoutingQuality: Double
    let lastVerifiedAt: String?
    let createdAt: String
    let updatedAt: String
}

struct NormalizedSourceRoutingPoint {
    let id: String
    let lat: Double
    let lon: Double
    let pointType: String
    let confidence: Double
    let derivedFrom: String?
    let createdAt: String?
}

struct DedupeReviewReport: Codable {
    let generatedAt: String
    let mergeRuleVersion: String
    let mergedCanonicalCount: Int
    let reviewCaseCount: Int
    let cases: [DedupeReviewCase]
}

struct DedupeReviewCase: Codable {
    let id: String
    let decision: String
    let reason: String
    let candidates: [DedupeReviewCandidate]
}

struct DedupeReviewCandidate: Codable {
    let sourceName: String
    let sourceIdentifier: String
    let displayName: String
    let city: String
    let placeType: String
    let objectLat: Double
    let objectLon: Double
}

struct CanonicalizationResult {
    let places: [DatasetPlaceRecord]
    let reviewReport: DedupeReviewReport
}

final class DedupeV1Canonicalizer {
    private enum MatchDecision {
        case exactDuplicate
        case autoMerge(reason: String)
        case review(reason: String)
        case separate(reason: String)
    }

    private struct MatchedGroup {
        let primary: NormalizedSourcePlaceRecord
        let members: [NormalizedSourcePlaceRecord]
    }

    private struct NameSignal {
        let allEqual: Bool
        let exactPair: Bool
        let anyPresent: Bool
    }

    func buildCanonicalizationResult(
        records: [NormalizedSourcePlaceRecord],
        generatedAt: String
    ) -> CanonicalizationResult {
        let uniqueRecords = collapseExactSourceDuplicates(records)
        let sortedRecords = uniqueRecords.sorted(by: preferredRecordOrder)

        var consumed = Set<String>()
        var reviewCases: [DedupeReviewCase] = []
        var reviewPairs = Set<String>()
        var canonicalPlaces: [DatasetPlaceRecord] = []

        for seed in sortedRecords {
            guard !consumed.contains(seed.stableID) else {
                continue
            }

            var mergedMembers = [seed]
            consumed.insert(seed.stableID)

            for candidate in sortedRecords where candidate.stableID != seed.stableID {
                if consumed.contains(candidate.stableID) {
                    continue
                }

                switch matchDecision(lhs: seed, rhs: candidate) {
                case .exactDuplicate:
                    consumed.insert(candidate.stableID)
                    mergedMembers.append(candidate)

                case .autoMerge:
                    consumed.insert(candidate.stableID)
                    mergedMembers.append(candidate)

                case .review(let reason):
                    let pairKey = reviewKey(lhs: seed, rhs: candidate)
                    if reviewPairs.insert(pairKey).inserted {
                        reviewCases.append(
                            DedupeReviewCase(
                                id: pairKey,
                                decision: "review",
                                reason: reason,
                                candidates: [seed, candidate].map(makeReviewCandidate)
                            )
                        )
                    }

                case .separate:
                    continue
                }
            }

            let group = MatchedGroup(
                primary: mergedMembers.sorted(by: preferredRecordOrder).first ?? seed,
                members: mergedMembers
            )
            canonicalPlaces.append(makeCanonicalPlace(from: group))
        }

        let reviewReport = DedupeReviewReport(
            generatedAt: generatedAt,
            mergeRuleVersion: "v1",
            mergedCanonicalCount: canonicalPlaces.count,
            reviewCaseCount: reviewCases.count,
            cases: reviewCases.sorted(by: { $0.id < $1.id })
        )

        return CanonicalizationResult(
            places: canonicalPlaces.sorted(by: { $0.id < $1.id }),
            reviewReport: reviewReport
        )
    }

    private func collapseExactSourceDuplicates(_ records: [NormalizedSourcePlaceRecord]) -> [NormalizedSourcePlaceRecord] {
        var seen = Set<String>()
        var unique: [NormalizedSourcePlaceRecord] = []

        for record in records.sorted(by: preferredRecordOrder) {
            let key = "\(record.sourceName)|\(record.sourceIdentifier)"
            if seen.insert(key).inserted {
                unique.append(record)
            }
        }

        return unique
    }

    private func matchDecision(lhs: NormalizedSourcePlaceRecord, rhs: NormalizedSourcePlaceRecord) -> MatchDecision {
        if lhs.sourceName == rhs.sourceName && lhs.sourceIdentifier == rhs.sourceIdentifier {
            return .exactDuplicate
        }

        if lhs.placeType != rhs.placeType {
            return .separate(reason: "place_type_mismatch")
        }

        if lhs.normalizedCity != rhs.normalizedCity {
            return .separate(reason: "city_mismatch")
        }

        let distance = haversineDistanceMeters(
            latitudeA: lhs.objectLat,
            longitudeA: lhs.objectLon,
            latitudeB: rhs.objectLat,
            longitudeB: rhs.objectLon
        )
        let nameSignal = nameSignal(lhs: lhs, rhs: rhs)
        let addressMatch = similarLabel(lhs.normalizedAddress, rhs.normalizedAddress)
        let namesConflict = bothValuesPresent(lhs.normalizedName, rhs.normalizedName) && !nameSignal.exactPair
        let addressesConflict = bothValuesPresent(lhs.normalizedAddress, rhs.normalizedAddress) && !addressMatch

        if namesConflict || addressesConflict {
            return .separate(reason: "text_conflict")
        }

        if distance <= 20 && (nameSignal.exactPair || addressMatch) {
            return .autoMerge(reason: "strong_spatial_and_text_match")
        }

        if distance <= 8 && !nameSignal.anyPresent && !addressMatch {
            return .autoMerge(reason: "strong_spatial_match_without_text")
        }

        if distance <= 40 && (nameSignal.exactPair || addressMatch) {
            return .review(reason: "near_match_requires_review")
        }

        if distance <= 15 && (nameSignal.anyPresent || lhs.addressOriginal != nil || rhs.addressOriginal != nil) {
            return .review(reason: "spatial_match_with_partial_text_support")
        }

        if distance <= 15 {
            return .review(reason: "spatial_only_match")
        }

        return .separate(reason: "distance_exceeds_threshold")
    }

    private func nameSignal(lhs: NormalizedSourcePlaceRecord, rhs: NormalizedSourcePlaceRecord) -> NameSignal {
        let labels = [lhs.normalizedName, rhs.normalizedName].compactMap { value -> String? in
            guard let value, !value.isEmpty else {
                return nil
            }
            return value
        }
        let allEqual = !labels.isEmpty && Set(labels).count == 1
        let exactPair = similarLabel(lhs.normalizedName, rhs.normalizedName)
        return NameSignal(allEqual: allEqual, exactPair: exactPair, anyPresent: !labels.isEmpty)
    }

    private func makeCanonicalPlace(from group: MatchedGroup) -> DatasetPlaceRecord {
        let members = group.members.sorted(by: preferredRecordOrder)
        let primary = group.primary
        let strongestEntrance = members.first(where: { $0.entranceLat != nil && $0.entranceLon != nil })
        let mergedRoutingPoints = mergeRoutingPoints(from: members)

        return DatasetPlaceRecord(
            id: primary.stableID,
            nameOriginal: selectText(from: members, keyPath: \.nameOriginal),
            nameEn: selectText(from: members, keyPath: \.nameEn),
            nameRu: selectText(from: members, keyPath: \.nameRu),
            nameHe: selectText(from: members, keyPath: \.nameHe),
            addressOriginal: selectText(from: members, keyPath: \.addressOriginal),
            addressEn: selectText(from: members, keyPath: \.addressEn),
            addressRu: selectText(from: members, keyPath: \.addressRu),
            addressHe: selectText(from: members, keyPath: \.addressHe),
            city: primary.city,
            placeType: primary.placeType,
            objectLat: primary.objectLat,
            objectLon: primary.objectLon,
            entranceLat: strongestEntrance?.entranceLat,
            entranceLon: strongestEntrance?.entranceLon,
            isPublic: members.contains(where: { $0.isPublic }),
            isAccessible: members.contains(where: { $0.isAccessible }),
            status: members.contains(where: { $0.status == "active" }) ? "active" : primary.status,
            confidenceScore: recalculatedConfidence(for: members),
            routingQuality: recalculatedRoutingQuality(for: members, hasEntrance: strongestEntrance != nil),
            lastVerifiedAt: members.compactMap(\.lastVerifiedAt).sorted().last,
            createdAt: members.map(\.createdAt).sorted().first ?? primary.createdAt,
            updatedAt: members.map(\.updatedAt).sorted().last ?? primary.updatedAt,
            sourceName: nil,
            sourceIdentifier: nil,
            routingPoints: mergedRoutingPoints,
            sourceAttributions: members.map { record in
                DatasetSourceAttributionRecord(
                    id: deterministicUUIDString(
                        from: "\(primary.stableID)|\(record.sourceName)|\(record.sourceIdentifier)"
                    ),
                    sourceName: record.sourceName,
                    sourceIdentifier: record.sourceIdentifier,
                    importedAt: record.updatedAt
                )
            }
        )
    }

    private func selectText(
        from members: [NormalizedSourcePlaceRecord],
        keyPath: KeyPath<NormalizedSourcePlaceRecord, String?>
    ) -> String? {
        for member in members {
            if let value = member[keyPath: keyPath]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func mergeRoutingPoints(from members: [NormalizedSourcePlaceRecord]) -> [DatasetRoutingPointRecord] {
        var merged: [DatasetRoutingPointRecord] = []
        var seen = Set<String>()

        for member in members {
            for routingPoint in member.routingPoints.sorted(by: { $0.id < $1.id }) {
                let key = "\(routingPoint.pointType)|\(rounded(routingPoint.lat))|\(rounded(routingPoint.lon))"
                guard seen.insert(key).inserted else {
                    continue
                }

                merged.append(
                    DatasetRoutingPointRecord(
                        id: routingPoint.id,
                        lat: routingPoint.lat,
                        lon: routingPoint.lon,
                        pointType: routingPoint.pointType,
                        confidence: routingPoint.confidence,
                        derivedFrom: routingPoint.derivedFrom,
                        createdAt: routingPoint.createdAt
                    )
                )
            }
        }

        return merged.sorted(by: { $0.id < $1.id })
    }

    private func recalculatedConfidence(for members: [NormalizedSourcePlaceRecord]) -> Double {
        var score = members.map(\.sourceConfidence).max() ?? 0.55

        if members.count > 1 {
            let maxDistance = maximumPairDistance(in: members)
            if maxDistance <= 10 {
                score += 0.08
            } else if maxDistance <= 25 {
                score += 0.05
            } else {
                score += 0.02
            }

            let names = members.compactMap(\.normalizedName).filter { !$0.isEmpty }
            if !names.isEmpty && Set(names).count == 1 {
                score += 0.03
            }

            let addresses = members.compactMap(\.normalizedAddress).filter { !$0.isEmpty }
            if !addresses.isEmpty && Set(addresses).count == 1 {
                score += 0.02
            }
        }

        return clamp(score, lower: 0.0, upper: 0.98)
    }

    private func recalculatedRoutingQuality(
        for members: [NormalizedSourcePlaceRecord],
        hasEntrance: Bool
    ) -> Double {
        var quality = members.map(\.sourceRoutingQuality).max() ?? 0.5

        if members.count > 1 {
            quality += 0.06
        }

        if hasEntrance {
            quality = max(quality, 0.82)
        }

        return clamp(quality, lower: 0.0, upper: 0.95)
    }

    private func maximumPairDistance(in members: [NormalizedSourcePlaceRecord]) -> Double {
        var maxDistance = 0.0

        for leftIndex in members.indices {
            for rightIndex in members.indices where rightIndex > leftIndex {
                let left = members[leftIndex]
                let right = members[rightIndex]
                let distance = haversineDistanceMeters(
                    latitudeA: left.objectLat,
                    longitudeA: left.objectLon,
                    latitudeB: right.objectLat,
                    longitudeB: right.objectLon
                )
                maxDistance = max(maxDistance, distance)
            }
        }

        return maxDistance
    }

    private func preferredRecordOrder(lhs: NormalizedSourcePlaceRecord, rhs: NormalizedSourcePlaceRecord) -> Bool {
        let leftPriority = sourcePriority(lhs.sourceName)
        let rightPriority = sourcePriority(rhs.sourceName)
        if leftPriority == rightPriority {
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.sourceIdentifier < rhs.sourceIdentifier
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        return leftPriority < rightPriority
    }

    private func sourcePriority(_ sourceName: String) -> Int {
        switch sourceName {
        case "beer-sheva-municipal-shelters":
            return 0
        case "beer-sheva-municipal-shelters-itm":
            return 1
        default:
            return 10
        }
    }

    private func makeReviewCandidate(from record: NormalizedSourcePlaceRecord) -> DedupeReviewCandidate {
        DedupeReviewCandidate(
            sourceName: record.sourceName,
            sourceIdentifier: record.sourceIdentifier,
            displayName: record.nameOriginal ?? record.nameHe ?? record.nameEn ?? record.sourceDisplayName,
            city: record.city,
            placeType: record.placeType,
            objectLat: record.objectLat,
            objectLon: record.objectLon
        )
    }

    private func reviewKey(lhs: NormalizedSourcePlaceRecord, rhs: NormalizedSourcePlaceRecord) -> String {
        [lhs.stableID, rhs.stableID].sorted().joined(separator: "__")
    }

    private func rounded(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        max(lower, min(upper, value))
    }
}

func deterministicUUIDString(from value: String) -> String {
    let digest = Array(SHA256.hash(data: Data(value.utf8)))
    let bytes = Array(digest.prefix(16))
    let tuple: uuid_t = (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5],
        (bytes[6] & 0x0F) | 0x50,
        bytes[7],
        (bytes[8] & 0x3F) | 0x80,
        bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuid: tuple).uuidString.lowercased()
}

func normalizedLabel(_ value: String?) -> String? {
    guard let value else {
        return nil
    }

    let filteredScalars = value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .unicodeScalars
        .filter { CharacterSet.alphanumerics.contains($0) }
    let normalized = String(String.UnicodeScalarView(filteredScalars)).lowercased()
    return normalized.isEmpty ? nil : normalized
}

private func similarLabel(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs, let rhs else {
        return false
    }

    return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
}

private func bothValuesPresent(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs, let rhs else {
        return false
    }

    return !lhs.isEmpty && !rhs.isEmpty
}

func haversineDistanceMeters(
    latitudeA: Double,
    longitudeA: Double,
    latitudeB: Double,
    longitudeB: Double
) -> Double {
    let radius = 6_371_000.0
    let lat1 = latitudeA * .pi / 180
    let lat2 = latitudeB * .pi / 180
    let deltaLat = (latitudeB - latitudeA) * .pi / 180
    let deltaLon = (longitudeB - longitudeA) * .pi / 180

    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
        + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return radius * c
}

struct ITM2039ToWGS84Converter {
    private let semiMajorAxis = 6_378_137.0
    private let inverseFlattening = 298.257222101
    private let scaleFactor = 1.0000067
    private let latitudeOfOrigin = 31.73439361111111 * .pi / 180
    private let longitudeOfOrigin = 35.20451694444444 * .pi / 180
    private let falseEasting = 219_529.584
    private let falseNorthing = 626_907.39

    // EPSG / Proj TOWGS84 parameters for Israel 1993 -> WGS84.
    private let deltaX = 23.772
    private let deltaY = 17.49
    private let deltaZ = 17.859
    private let rotationXArcSeconds = -0.3132
    private let rotationYArcSeconds = -1.85274
    private let rotationZArcSeconds = 1.67299
    private let scalePPM = -5.4262

    private var flattening: Double {
        1.0 / inverseFlattening
    }

    private var eccentricitySquared: Double {
        let value = flattening
        return value * (2 - value)
    }

    private var secondEccentricitySquared: Double {
        eccentricitySquared / (1 - eccentricitySquared)
    }

    func convert(northing: Double, easting: Double) -> (latitude: Double, longitude: Double) {
        let sourceGeodetic = inverseTransverseMercator(northing: northing, easting: easting)
        return applyHelmertToWGS84(latitude: sourceGeodetic.latitude, longitude: sourceGeodetic.longitude)
    }

    private func inverseTransverseMercator(northing: Double, easting: Double) -> (latitude: Double, longitude: Double) {
        let x = easting - falseEasting
        let y = northing - falseNorthing
        let meridionalArc = meridionalArcAtOrigin() + (y / scaleFactor)
        let e1 = (1 - sqrt(1 - eccentricitySquared)) / (1 + sqrt(1 - eccentricitySquared))
        let mu = meridionalArc / (
            semiMajorAxis * (
                1
                    - eccentricitySquared / 4
                    - 3 * pow(eccentricitySquared, 2) / 64
                    - 5 * pow(eccentricitySquared, 3) / 256
            )
        )

        let phi1 = mu
            + (3 * e1 / 2 - 27 * pow(e1, 3) / 32) * sin(2 * mu)
            + (21 * pow(e1, 2) / 16 - 55 * pow(e1, 4) / 32) * sin(4 * mu)
            + (151 * pow(e1, 3) / 96) * sin(6 * mu)
            + (1097 * pow(e1, 4) / 512) * sin(8 * mu)

        let c1 = secondEccentricitySquared * pow(cos(phi1), 2)
        let t1 = pow(tan(phi1), 2)
        let n1 = semiMajorAxis / sqrt(1 - eccentricitySquared * pow(sin(phi1), 2))
        let r1 = semiMajorAxis * (1 - eccentricitySquared)
            / pow(1 - eccentricitySquared * pow(sin(phi1), 2), 1.5)
        let d = x / (n1 * scaleFactor)

        let latitude = phi1 - (n1 * tan(phi1) / r1) * (
            pow(d, 2) / 2
                - (5 + 3 * t1 + 10 * c1 - 4 * pow(c1, 2) - 9 * secondEccentricitySquared) * pow(d, 4) / 24
                + (61 + 90 * t1 + 298 * c1 + 45 * pow(t1, 2) - 252 * secondEccentricitySquared - 3 * pow(c1, 2))
                * pow(d, 6) / 720
        )

        let longitude = longitudeOfOrigin + (
            d
                - (1 + 2 * t1 + c1) * pow(d, 3) / 6
                + (5 - 2 * c1 + 28 * t1 - 3 * pow(c1, 2) + 8 * secondEccentricitySquared + 24 * pow(t1, 2))
                * pow(d, 5) / 120
        ) / cos(phi1)

        return (latitude: latitude, longitude: longitude)
    }

    private func applyHelmertToWGS84(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        let sourceECEF = geodeticToECEF(latitude: latitude, longitude: longitude)
        let rotationX = rotationXArcSeconds * .pi / (180 * 3600)
        let rotationY = rotationYArcSeconds * .pi / (180 * 3600)
        let rotationZ = rotationZArcSeconds * .pi / (180 * 3600)
        let scale = scalePPM * 1e-6

        let x = deltaX + (1 + scale) * sourceECEF.x - rotationZ * sourceECEF.y + rotationY * sourceECEF.z
        let y = deltaY + rotationZ * sourceECEF.x + (1 + scale) * sourceECEF.y - rotationX * sourceECEF.z
        let z = deltaZ - rotationY * sourceECEF.x + rotationX * sourceECEF.y + (1 + scale) * sourceECEF.z

        let target = ecefToWGS84Geodetic(x: x, y: y, z: z)
        return (
            latitude: target.latitude * 180 / .pi,
            longitude: target.longitude * 180 / .pi
        )
    }

    private func meridionalArcAtOrigin() -> Double {
        meridionalArc(for: latitudeOfOrigin)
    }

    private func meridionalArc(for latitude: Double) -> Double {
        let e2 = eccentricitySquared
        return semiMajorAxis * (
            (1 - e2 / 4 - 3 * pow(e2, 2) / 64 - 5 * pow(e2, 3) / 256) * latitude
                - (3 * e2 / 8 + 3 * pow(e2, 2) / 32 + 45 * pow(e2, 3) / 1024) * sin(2 * latitude)
                + (15 * pow(e2, 2) / 256 + 45 * pow(e2, 3) / 1024) * sin(4 * latitude)
                - (35 * pow(e2, 3) / 3072) * sin(6 * latitude)
        )
    }

    private func geodeticToECEF(latitude: Double, longitude: Double) -> (x: Double, y: Double, z: Double) {
        let sinLatitude = sin(latitude)
        let radius = semiMajorAxis / sqrt(1 - eccentricitySquared * sinLatitude * sinLatitude)
        let x = radius * cos(latitude) * cos(longitude)
        let y = radius * cos(latitude) * sin(longitude)
        let z = radius * (1 - eccentricitySquared) * sinLatitude
        return (x: x, y: y, z: z)
    }

    private func ecefToWGS84Geodetic(x: Double, y: Double, z: Double) -> (latitude: Double, longitude: Double) {
        let wgs84SemiMajorAxis = 6_378_137.0
        let wgs84Flattening = 1.0 / 298.257223563
        let wgs84EccentricitySquared = wgs84Flattening * (2 - wgs84Flattening)

        let longitude = atan2(y, x)
        let p = sqrt(x * x + y * y)
        var latitude = atan2(z, p * (1 - wgs84EccentricitySquared))

        for _ in 0..<8 {
            let sinLatitude = sin(latitude)
            let radius = wgs84SemiMajorAxis / sqrt(1 - wgs84EccentricitySquared * sinLatitude * sinLatitude)
            latitude = atan2(z + wgs84EccentricitySquared * radius * sinLatitude, p)
        }

        return (latitude: latitude, longitude: longitude)
    }
}
