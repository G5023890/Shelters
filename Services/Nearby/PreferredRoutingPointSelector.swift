import Foundation

protocol PreferredRoutingPointSelecting: Sendable {
    func resolve(for place: CanonicalPlace, routingPoints: [RoutingPoint]) -> ResolvedRoutingTarget
}

struct PreferredRoutingPointSelector: PreferredRoutingPointSelecting {
    func resolve(for place: CanonicalPlace, routingPoints: [RoutingPoint]) -> ResolvedRoutingTarget {
        if let entranceCoordinate = place.entranceCoordinate, place.status != .removed {
            return ResolvedRoutingTarget(
                coordinate: entranceCoordinate,
                pointType: .entrance,
                source: .placeEntrance
            )
        }

        if let bestRoutingPoint = bestRoutingPoint(from: routingPoints) {
            return ResolvedRoutingTarget(
                coordinate: bestRoutingPoint.coordinate,
                pointType: bestRoutingPoint.pointType,
                source: .routingPoint
            )
        }

        if let preferredRoutingCoordinate = place.preferredRoutingCoordinate {
            return ResolvedRoutingTarget(
                coordinate: preferredRoutingCoordinate,
                pointType: place.preferredRoutingPointType ?? .preferred,
                source: .storedPreferred
            )
        }

        return ResolvedRoutingTarget(
            coordinate: place.objectCoordinate,
            pointType: .object,
            source: .objectFallback
        )
    }

    private func bestRoutingPoint(from routingPoints: [RoutingPoint]) -> RoutingPoint? {
        routingPoints.sorted {
            let lhsRank = typePriority($0.pointType)
            let rhsRank = typePriority($1.pointType)

            if lhsRank == rhsRank {
                if $0.confidence == $1.confidence {
                    return $0.createdAt < $1.createdAt
                }

                return $0.confidence > $1.confidence
            }

            return lhsRank < rhsRank
        }
        .first
    }

    private func typePriority(_ pointType: RoutingPointType) -> Int {
        switch pointType {
        case .entrance:
            return 0
        case .preferred:
            return 1
        case .userSubmitted:
            return 2
        case .inferred:
            return 3
        case .object:
            return 4
        }
    }
}

