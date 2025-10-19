import Foundation

// Helper to encode/decode Any values in JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

struct ExportPhotoInfo: Codable {
    let photoID: String
    let dateTimeOriginal: String
    let latitude: String
    let longitude: String
    let qrCode: String?
    let temperatureC: String
    let temperatureF: String
    let notes: String
    let collector: String
    let location: String
    let address: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case photoID, dateTimeOriginal, latitude, longitude, qrCode, temperatureC, temperatureF, notes, collector, location, address
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photoID, forKey: .photoID)
        try container.encode(dateTimeOriginal, forKey: .dateTimeOriginal)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(temperatureC, forKey: .temperatureC)
        try container.encode(temperatureF, forKey: .temperatureF)
        try container.encode(notes, forKey: .notes)
        try container.encode(collector, forKey: .collector)
        try container.encode(location, forKey: .location)
        if let qrCode = qrCode, !qrCode.isEmpty {
            try container.encode(qrCode, forKey: .qrCode)
        }
        if let address = address {
            try container.encode(address, forKey: .address)
        }
    }
}