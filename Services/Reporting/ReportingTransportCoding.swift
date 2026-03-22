import Foundation

enum ReportingTransportCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateCoding.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { container in
            let value = try container.singleValueContainer().decode(String.self)

            if let date = DateCoding.date(from: value) {
                return date
            }

            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported date format: \(value)"
                )
            )
        }
        return decoder
    }
}
