import Foundation

func textOrNull(_ value: String?) -> SQLiteValue {
    value.map(SQLiteValue.text) ?? .null
}

func doubleOrNull(_ value: Double?) -> SQLiteValue {
    value.map(SQLiteValue.double) ?? .null
}

func makeCoordinate(lat: Double?, lon: Double?) -> GeoCoordinate? {
    guard let lat, let lon else { return nil }
    return GeoCoordinate(latitude: lat, longitude: lon)
}

