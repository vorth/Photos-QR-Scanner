import Photos
import Foundation

struct PhotoInfo: Identifiable {
    let id = UUID()
    let photoID: String
    let dateTimeOriginal: String
    let latLong: String
    var qrCode: String
    var temperatureC: String
    var temperatureF: String
    var notes: String = ""
    var collector: String = ""
    var location: String = "Searching..."
    var address: [String: Any]?
    let asset: PHAsset
    
    var elevation: String {
        guard let address = address,
              let elevation = address["elevation"] as? String else {
            return "N/A"
        }
        return elevation
    }
    
    init(asset: PHAsset) {
        self.asset = asset
        self.photoID = asset.localIdentifier
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // "2025-10-14 14:30:45"
        
        self.dateTimeOriginal = asset.creationDate.map { formatter.string(from: $0) } ?? "Unknown"
        
        // Extract GPS coordinates
        if let location = asset.location {
            let lat = String(format: "%.5f", location.coordinate.latitude)
            let lng = String(format: "%.5f", location.coordinate.longitude)
            self.latLong = "\(lat), \(lng)"
        } else {
            self.latLong = "No location"
        }
        
        // QR code will be detected asynchronously
        self.qrCode = "Scanning..."

        // Temperature data will be added asynchronously
        self.temperatureC = "Searching..."
        self.temperatureF = "Searching..."
    }
}