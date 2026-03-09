import CoreLocation
import Foundation

struct LocationFetcher {
    
    // MARK: - Fetch Location with OpenStreetMap and Elevation
    
    static func fetchLocation(at coordinate: CLLocationCoordinate2D, completion: @escaping (String, [String: Any]?) -> Void) {
        let urlString = "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&zoom=9"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.addValue("Photos-QR-Scanner", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var address = json["address"] as? [String: Any] else {
                DispatchQueue.main.async {
                    completion("Unknown", nil)
                }
                return
            }
            
            let location = json["display_name"] as? String ?? "Unknown"
            
            // Fetch elevation from Open-Elevation API
            fetchElevation(at: coordinate) { elevation in
                if let elevationMeters = elevation {
                    let elevationFeet = elevationMeters * 3.28084
                    address["elevation"] = String(format: "%.0fm/%.0fft", elevationMeters, elevationFeet)
                }
                
                DispatchQueue.main.async {
                    completion(location, address)
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Elevation from Open-Elevation API
    
    static func fetchElevation(at coordinate: CLLocationCoordinate2D, completion: @escaping (Double?) -> Void) {
        let urlString = "https://api.open-elevation.com/api/v1/lookup?locations=\(coordinate.latitude),\(coordinate.longitude)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  let elevation = firstResult["elevation"] as? Double else {
                completion(nil)
                return
            }
            
            completion(elevation)
        }.resume()
    }
}