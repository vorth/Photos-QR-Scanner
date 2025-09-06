import SwiftUI
import Photos
import Vision
import CoreGraphics
import CoreLocation

struct PhotoMetadataApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ExportPhotoInfo: Codable {
    let photoID: String
    let dateTimeOriginal: String
    let latitude: String
    let longitude: String
    let qrCode: String
    let temperatureC: String
    let temperatureF: String
    let notes: String
}

struct PhotoInfo: Identifiable {
    let id = UUID()
    let photoID: String
    let dateTimeOriginal: String
    let latLong: String
    var qrCode: String
    var temperatureC: String
    var temperatureF: String
    var notes: String = ""
    let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
        self.photoID = asset.localIdentifier
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
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
            // Return times in UTC so we can compare directly.
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

            // Convert the photo’s date to UTC hour strings (e.g. "2023-04-15T14:00").
            let hourFormatter = DateFormatter()
            hourFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:00"

            // Find the hour that is closest to the photo timestamp.
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

struct ContentView: View {
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
    @State private var selectedPhotoInfos: [PhotoInfo] = []
    @State private var qrCodeResults: [String: String] = [:]
    @State private var thumbnailSize: Double = 100
    @State private var photoNotes: [String: String] = [:]
    
    var body: some View {
        mainView
            .navigationTitle("Photos Metadata")
            .onAppear {
                checkPermissions()
            }
    }
    
    private var mainView: some View {
        Group {
            if authStatus == .authorized || authStatus == .limited {
                HSplitView {
                    photoGridView
                        .frame(minWidth: 250, idealWidth: 400, maxWidth: .infinity)
                    metadataTableView
                        .frame(minWidth: 350, idealWidth: 500, maxWidth: .infinity)
                }
            } else {
                permissionView
            }
        }
    }
    
    private var photoGridView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Recent Photos (\(allPhotos.count))")
                    .font(.headline)
                
                Spacer()
                
                Text("Size:")
                    .font(.caption)
                Slider(value: $thumbnailSize, in: 80...300, step: 20)
                    .frame(width: 100)
                Text("\(Int(thumbnailSize))px")
                    .font(.caption)
                    .frame(width: 40)
            }
            .padding()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: thumbnailSize), spacing: 6)
                ], spacing: 6) {
                    ForEach(allPhotos.indices, id: \.self) { index in
                        let asset = allPhotos[index]
                        ThumbnailView(
                            asset: asset,
                            isSelected: selectedIDs.contains(asset.localIdentifier),
                            size: thumbnailSize,
                            onTap: {
                                toggleSelection(asset)
                            },
                            qrCodeResult: qrCodeResults[asset.localIdentifier] // <-- Pass QR code result
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var metadataTableView: some View {
        VStack(alignment: .leading) {
            Text("Selected Photos (\(selectedPhotoInfos.count))")
                .font(.headline)
                .padding()
            
            Button("Export to JSON") {
                exportSelectedPhotosToJSON()
            }
            .padding(.horizontal)
            .disabled(selectedPhotoInfos.isEmpty)

            if selectedPhotoInfos.isEmpty {
                Text("Select photos to view metadata")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(selectedPhotoInfos) {
                    TableColumn("Photo ID") { photoInfo in
                        Text(photoInfo.photoID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                            .underline()
                            .onTapGesture {
                                deselectPhoto(photoInfo.photoID)
                            }
                    }
                    
                    TableColumn("Date/Time Original") { photoInfo in
                        Text(photoInfo.dateTimeOriginal)
                            .font(.caption)
                    }
                    
                    TableColumn("Lat/Long") { photoInfo in
                        Text(photoInfo.latLong)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    
                    TableColumn("QR Code") { photoInfo in
                        Text(qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    
                    TableColumn("Temp (°C)") { photoInfo in
                        Text(photoInfo.temperatureC)
                            .font(.caption)
                    }
                    
                    TableColumn("Temp (°F)") { photoInfo in
                        Text(photoInfo.temperatureF)
                            .font(.caption)
                    }
                    
                    TableColumn("Notes") { photoInfo in
                        TextField("Notes", text: Binding(
                            get: { photoNotes[photoInfo.photoID, default: ""] },
                            set: { photoNotes[photoInfo.photoID] = $0 }
                        ))
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Text("Photos Access Required")
                .font(.title2)
            
            Text("Please grant access to your Photos library")
                .foregroundColor(.secondary)
            
            Button("Grant Access") {
                requestAccess()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func checkPermissions() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .authorized || authStatus == .limited {
            loadRecentPhotos()
        }
    }
    
    private func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authStatus = status
                if status == .authorized || status == .limited {
                    loadRecentPhotos()
                }
            }
        }
    }
    
    private func loadRecentPhotos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 200
        
        let result = PHAsset.fetchAssets(with: .image, options: options)
        
        var photos: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            photos.append(asset)
        }
        
        DispatchQueue.main.async {
            allPhotos = photos
        }
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            selectedPhotoInfos.removeAll { $0.photoID == id }
            qrCodeResults.removeValue(forKey: id)
        } else {
            selectedIDs.insert(id)
            let photoInfo = PhotoInfo(asset: asset)
            selectedPhotoInfos.append(photoInfo)
            
            // Start QR code detection for newly selected photo
            detectQRCode(for: asset)
            
            guard let location = asset.location,
                  let creation = asset.creationDate else {
                print("No GPS or no creation date – cannot fetch historic temperature.")
                return
            }
    
            WeatherFetcher.fetchHistoricTemp(at: location.coordinate,
                                             on: creation) { tempC in
                DispatchQueue.main.async(execute: {
                    if let idx = selectedPhotoInfos.firstIndex(where: { $0.photoID == id }) {
                         selectedPhotoInfos[idx].temperatureC = tempC != nil ?
                            String(format: "%.1f°C", tempC!) : "—"
                         let f = tempC != nil ? tempC! * 9.0/5.0 + 32.0 : nil
                         selectedPhotoInfos[idx].temperatureF = f != nil ?
                            String(format: "%.1f°F", f!) : "—"
                        
                        print("Historic temperature for \(id):",
                              tempC.map { "\($0)°C" } ?? "unknown")
                    }
                })
            }
        }
    }
    
    private func deselectPhoto(_ photoID: String) {
        selectedIDs.remove(photoID)
        selectedPhotoInfos.removeAll { $0.photoID == photoID }
        qrCodeResults.removeValue(forKey: photoID)
    }
    
    private func detectQRCode(for asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024), // Higher resolution for QR detection
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image else {
                DispatchQueue.main.async {
                    qrCodeResults[asset.localIdentifier] = "No QR code"
                }
                return
            }
            
            // Convert NSImage to CGImage for macOS
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    qrCodeResults[asset.localIdentifier] = "No QR code"
                }
                return
            }
            
            let request = VNDetectBarcodesRequest { request, error in
                DispatchQueue.main.async {
                    let result: String
                    if let results = request.results as? [VNBarcodeObservation],
                       let firstQR = results.first(where: { $0.symbology == .QR }),
                       let qrString = firstQR.payloadStringValue {
                        result = qrString
                    } else {
                        result = "No QR code"
                    }
                    
                    qrCodeResults[asset.localIdentifier] = result
                    
                    // Force UI update by updating the PhotoInfo object
                    if let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == asset.localIdentifier }) {
                        selectedPhotoInfos[index].qrCode = result
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func exportSelectedPhotosToJSON() {
        let exportData = selectedPhotoInfos.map { info in
            let latLongParts = info.latLong.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let latitude = latLongParts.count == 2 ? latLongParts[0] : ""
            let longitude = latLongParts.count == 2 ? latLongParts[1] : ""
            let tempC = info.temperatureC.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
            let tempF = info.temperatureF.replacingOccurrences(of: "°F", with: "").trimmingCharacters(in: .whitespaces)
            return ExportPhotoInfo(
                photoID: info.photoID,
                dateTimeOriginal: info.dateTimeOriginal,
                latitude: latitude,
                longitude: longitude,
                qrCode: qrCodeResults[info.photoID] ?? info.qrCode,
                temperatureC: tempC,
                temperatureF: tempF,
                notes: photoNotes[info.photoID] ?? ""
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(exportData)
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")

                let panel = NSSavePanel()
                panel.nameFieldStringValue = "photo_scan_metadata.json"
                panel.allowedFileTypes = ["json"]
                if panel.runModal() == .OK, let url = panel.url {
                    try jsonString.write(to: url, atomically: true, encoding: .utf8)
                    print("Exported to \(url.path)")
                }

            } else {
                print("Failed to encode JSON as UTF-8 string.")
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
}

struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let size: Double
    let onTap: () -> Void
    let qrCodeResult: String?
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: size, height: size)
            
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            
            if isSelected {
                Rectangle()
                    .fill(selectionColor.opacity(0.3)) // <-- use selectionColor
                    .frame(width: size, height: size)
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: selectionIcon) // <-- use selectionIcon
                            .foregroundColor(.white)
                            .background(selectionColor)
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
                if qrCodeResult == "No QR code" {
                    Text("No QR Code")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(4)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? selectionColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1) // <-- use selectionColor
        )
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    // Computed properties for color and icon
    private var selectionColor: Color {
        if let qr = qrCodeResult, qr == "No QR code" {
            return .red
        }
        return .blue
    }

    private var selectionIcon: String {
        if let qr = qrCodeResult, qr == "No QR code" {
            return "xmark.circle.fill"
        }
        return "checkmark.circle.fill"
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        
        // Account for Retina displays - request 2x or 3x the display size
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let targetSize = CGSize(width: size * scale, height: size * scale)
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                thumbnail = image
            }
        }
    }
}
