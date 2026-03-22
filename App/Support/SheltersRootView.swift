import SwiftUI

public struct SheltersRootView: View {
    @StateObject private var bootstrapper = AppBootstrapper()

    public init() {}

    public var body: some View {
        Group {
            switch bootstrapper.state {
            case .idle, .loading:
                BootstrapLoadingView()
            case .failed(let message):
                BootstrapErrorView(message: message) {
                    await bootstrapper.bootstrap()
                }
            case .ready(let container):
                RootTabView(container: container)
                    .environmentObject(container.settingsStore)
                    .environment(\.locale, Locale(identifier: container.settingsStore.activeLanguage.rawValue))
                    .environment(\.layoutDirection, container.settingsStore.activeLanguage.layoutDirection)
            }
        }
        .task {
            await bootstrapper.bootstrapIfNeeded()
        }
    }
}

private struct BootstrapLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L10n.text(.bootstrapLoading))
                .font(.headline)
        }
        .padding(24)
    }
}

private struct BootstrapErrorView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(L10n.text(.bootstrapFailedTitle))
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task {
                    await retry()
                }
            } label: {
                Text(L10n.text(.commonRetry))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

