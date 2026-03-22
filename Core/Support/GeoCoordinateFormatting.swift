import Foundation

extension GeoCoordinate {
    func formattedString(decimals: Int = 5) -> String {
        String(
            format: "%.\(decimals)f, %.\(decimals)f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitude,
            longitude
        )
    }
}
