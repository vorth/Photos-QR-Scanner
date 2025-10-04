import Foundation

struct ExportPhotoInfo: Codable {
    let photoID: String
    let dateTimeOriginal: String
    let latitude: String
    let longitude: String
    let qrCode: String?
    let temperatureC: String
    let temperatureF: String
    let notes: String
    let country: String
    let state: String
    let county: String
    
    enum CodingKeys: String, CodingKey {
        case photoID, dateTimeOriginal, latitude, longitude, qrCode, temperatureC, temperatureF, notes, country, state, county
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
        try container.encode(country, forKey: .country)
        try container.encode(state, forKey: .state)
        try container.encode(county, forKey: .county)
        if let qrCode = qrCode, !qrCode.isEmpty {
            try container.encode(qrCode, forKey: .qrCode)
        }
    }
}