import CoreLocation
import Foundation

struct LocationFetcher {
    static func fetchLocation(at coordinate: CLLocationCoordinate2D, completion: @escaping (String, [String: Any]?) -> Void) {
        let urlString = "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&zoom=9"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.addValue("Photos-QR-Scanner", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let address = json["address"] as? [String: Any] else {
                DispatchQueue.main.async {
                    completion("Unknown",  nil)
                }
                return
            }
            
            let location = json["display_name"] as? String ?? "Unknown"
            
            DispatchQueue.main.async {
                completion(location, address)
            }
        }.resume()
    }
}