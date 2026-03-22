import SwiftUI

struct RootTabView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            MapPreviewView(
                placeRepository: container.placeRepository,
                routingPointRepository: container.routingPointRepository,
                locationService: container.locationService,
                settingsStore: container.settingsStore
            )
            .tabItem {
                Label {
                    Text(L10n.text(.mapPreviewTitle))
                } icon: {
                    Image(systemName: "map")
                }
            }

            NearbyHomeView(
                nearbySearchService: container.nearbySearchService,
                locationService: container.locationService,
                syncService: container.syncService,
                routingService: container.routingService,
                reportingService: container.reportingService,
                placeRepository: container.placeRepository,
                routingPointRepository: container.routingPointRepository,
                sourceAttributionRepository: container.sourceAttributionRepository,
                settingsStore: container.settingsStore
            )
            .tabItem {
                Label {
                    Text(L10n.text(.nearbyTitle))
                } icon: {
                    Image(systemName: "location.viewfinder")
                }
            }

            ReportingView(
                reportingService: container.reportingService,
                locationService: container.locationService,
                syncService: container.syncService,
                diagnostics: container.environmentConfiguration.diagnostics
            )
                .tabItem {
                    Label {
                        Text(L10n.text(.reportingTitle))
                    } icon: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                }

            SettingsView(
                syncService: container.syncService,
                settingsStore: container.settingsStore,
                diagnostics: container.environmentConfiguration.diagnostics
            )
            .tabItem {
                Label {
                    Text(L10n.text(.settingsTitle))
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}
