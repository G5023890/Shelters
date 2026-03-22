import Foundation
import SwiftUI

@MainActor
final class AppBootstrapper: ObservableObject {
    enum State {
        case idle
        case loading
        case ready(AppContainer)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func bootstrapIfNeeded() async {
        guard case .idle = state else { return }
        await bootstrap()
    }

    func bootstrap() async {
        state = .loading

        do {
            let container = try AppContainer.bootstrap()
            state = .ready(container)
            await container.settingsStore.load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

