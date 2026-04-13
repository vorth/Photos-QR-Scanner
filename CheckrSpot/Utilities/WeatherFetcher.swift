import CoreLocation
import Foundation

struct WeatherFetcher {
    /// Returns the temperature (°C) that was reported at the hour closest to `date`.
    /// - Parameters:
    ///   - coordinate: GPS of the photo.
    ///   - date: Exact moment the photo was taken (taken from `PHAsset.creationDate`).
    ///   - completion: Temperature in Celsius, or `nil` if anything fails.
    static func fetchHistoricTemp(at coordinate: CLLocationCoordinate2D,
                                  on date: Date,
                                  completion: @escaping (Double?) -> Void) {
        // The weather API we're using, Open‑Meteo, expects dates in YYYY‑MM‑DD format.
        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)   // work in UTC for the API
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dayString = dayFormatter.string(from: date)

        // Build the forecast URL – we ask only for the hourly temperature series.
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",  value: "\(coordinate.latitude)"),
            URLQueryItem(name: "longitude", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "hourly",     value: "temperature_2m"),
            URLQueryItem(name: "timezone",   value: "UTC"),
            URLQueryItem(name: "past_days", value: "31"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = comps.url else { completion(nil); return }

        URLSession.shared.dataTask(with: url) { data, _, err in
            guard err == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let hourly = json["hourly"] as? [String:Any],
                  let times = hourly["time"] as? [String],
                  let temps = hourly["temperature_2m"] as? [Double],
                  times.count == temps.count else {
                completion(nil)
                return
            }

            let hourFormatter = DateFormatter()
            hourFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:00"

            var bestIdx: Int?
            var smallestDiff = TimeInterval.greatestFiniteMagnitude

            for (idx, isoString) in times.enumerated() {
                guard let hourDate = hourFormatter.date(from: isoString) else { continue }
                let diff = abs(hourDate.timeIntervalSince(date))
                if diff < smallestDiff {
                    smallestDiff = diff
                    bestIdx = idx
                }
            }

            if let i = bestIdx {
                completion(temps[i])
            } else {
                completion(nil)
            }
        }.resume()
    }
}