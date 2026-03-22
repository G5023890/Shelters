import Foundation

protocol ClientVersionProviding: Sendable {
    func currentVersion() -> String
}

struct BundleClientVersionProvider: ClientVersionProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func currentVersion() -> String {
        if let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !shortVersion.isEmpty {
            return shortVersion
        }

        if let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !buildVersion.isEmpty {
            return buildVersion
        }

        return "0"
    }
}
