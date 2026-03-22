import SwiftUI

extension AppLanguage {
    var layoutDirection: LayoutDirection {
        switch self {
        case .hebrew:
            return .rightToLeft
        case .english, .russian:
            return .leftToRight
        }
    }
}
