import CoreLocation
import Foundation

struct LocationFetcher {
    
    // Fetch Location with CoreLocation Reverse Geocoding and Elevation
    //
    //  The elevation fetching is fine.  For the location description, however,
    //    we probably want to roll back to using the approach we had, or maybe keep aspects of both.
    //  I think we should make a location description field that is optional and editable,
    //    so users can enter their own location description if they want, or refine the one we fetch.
    
    static func fetchLocation(at coordinate: CLLocationCoordinate2D, completion: @escaping (String, [String: Any]?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        // Perform reverse geocoding using CoreLocation
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else {
                DispatchQueue.main.async {
                    completion("Unknown", nil)
                }
                return
            }
            
            // Format the display name
            let displayName = formatPlacemark(placemark)
            
            // Create address dictionary
            var address: [String: Any] = [:]
            if let name = placemark.name { address["name"] = name }
            if let thoroughfare = placemark.thoroughfare { address["road"] = thoroughfare }
            if let subThoroughfare = placemark.subThoroughfare { address["house_number"] = subThoroughfare }
            if let locality = placemark.locality { address["city"] = locality }
            if let subLocality = placemark.subLocality { address["suburb"] = subLocality }
            if let administrativeArea = placemark.administrativeArea { address["state"] = administrativeArea }
            if let subAdministrativeArea = placemark.subAdministrativeArea { address["county"] = subAdministrativeArea }
            if let postalCode = placemark.postalCode { address["postcode"] = postalCode }
            if let country = placemark.country { address["country"] = country }
            if let isoCountryCode = placemark.isoCountryCode { address["country_code"] = isoCountryCode }
            
            // Fetch elevation from Open-Elevation API
            fetchElevation(at: coordinate) { elevation in
                if let elevationMeters = elevation {
                    let elevationFeet = elevationMeters * 3.28084
                    address["elevation"] = String(format: "%.0fm / %.0fft", elevationMeters, elevationFeet)
                }
                
                DispatchQueue.main.async {
                    completion(displayName, address)
                }
            }
        }
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
    
    // MARK: - Helper Methods
    
    private static func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let name = placemark.name, name != placemark.locality {
            components.append(name)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
    }
}