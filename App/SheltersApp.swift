import SwiftUI
import SheltersKit

@main
struct SheltersApp: App {
    var body: some Scene {
        WindowGroup {
            SheltersRootView()
        }
#if os(macOS)
        .defaultSize(width: 1480, height: 940)
#endif
    }
}
