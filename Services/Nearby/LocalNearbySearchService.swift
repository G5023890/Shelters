import Foundation

final class LocalNearbySearchService: NearbySearchService {
    private let placeRepository: CanonicalPlaceRepository
    private let routingPointRepository: RoutingPointRepository
    private let routingTargetSelector: PreferredRoutingPointSelecting
    private let ranker: NearbyPlaceRanker

    init(
        placeRepository: CanonicalPlaceRepository,
        routingPointRepository: RoutingPointRepository,
        routingTargetSelector: PreferredRoutingPointSelecting = PreferredRoutingPointSelector(),
        ranker: NearbyPlaceRanker = NearbyPlaceRanker()
    ) {
        self.placeRepository = placeRepository
        self.routingPointRepository = routingPointRepository
        self.routingTargetSelector = routingTargetSelector
        self.ranker = ranker
    }

    func searchNearby(from coordinate: GeoCoordinate, radiusMeters: Double, limit: Int) async throws -> [NearbyPlaceCandidate] {
        let effectiveRadius = min(radiusMeters, ShelterAccessPolicy.maxEmergencyWalkingDistanceMeters)
        let places = try placeRepository.fetchNearbyCandidates(
            around: coordinate,
            radiusMeters: effectiveRadius,
            limit: limit * 4
        )

        return try places
            .map { place in
                let routingPoints = try routingPointRepository.fetchRoutingPoints(for: place.id)
                let routingTarget = routingTargetSelector.resolve(for: place, routingPoints: routingPoints)
                let distance = DistanceCalculator.meters(from: coordinate, to: routingTarget.coordinate)
                let score = ranker.score(
                    place: place,
                    routingTarget: routingTarget,
                    distanceMeters: distance,
                    searchRadiusMeters: radiusMeters
                )

                return NearbyPlaceCandidate(
                    id: place.id,
                    place: place,
                    routingTarget: routingTarget,
                    distanceMeters: distance,
                    estimatedWalkingMinutes: DistanceCalculator.estimatedWalkingMinutes(forMeters: distance),
                    rankingScore: score
                )
            }
            .filter { ShelterAccessPolicy.isWithinEmergencyWalkingWindow(distanceMeters: $0.distanceMeters) }
            .sorted {
                if $0.rankingScore == $1.rankingScore {
                    return $0.distanceMeters < $1.distanceMeters
                }
                return $0.rankingScore > $1.rankingScore
            }
            .prefix(limit)
            .map { $0 }
    }

    func recentPlaces(limit: Int) async throws -> [CanonicalPlace] {
        try placeRepository.fetchAll(limit: limit)
    }
}
