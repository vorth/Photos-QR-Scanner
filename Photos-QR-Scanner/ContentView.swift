import SwiftUI
import Photos
import Vision
import CoreGraphics
import CoreLocation

struct ContentView: View {
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
    @State private var selectedPhotoInfos: [PhotoInfo] = []
    @State private var qrCodeResults: [String: String] = [:]
    @State private var thumbnailSize: Double = 100
    @State private var photoNotes: [String: String] = [:]
    @State private var manualQRCodes: [String: String] = [:]
    @State private var editingPhoto: PhotoInfo? = nil
    
    var body: some View {
        mainView
            .navigationTitle("Photos Metadata")
            .onAppear {
                checkPermissions()
            }
            .sheet(item: $editingPhoto) { photoInfo in
                EditPhotoView(
                    photoInfo: photoInfo,
                    qrCode: qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode,
                    notes: photoNotes[photoInfo.photoID, default: ""]
                ) { editedInfo in
                    // Update the corresponding PhotoInfo in selectedPhotoInfos
                    if let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == photoInfo.photoID }) {
                        selectedPhotoInfos[index].qrCode = editedInfo.qrCode
                        selectedPhotoInfos[index].notes = editedInfo.notes
                    }
                    
                    // Update QR code result and notes immediately
                    qrCodeResults[photoInfo.photoID] = editedInfo.qrCode
                    photoNotes[photoInfo.photoID] = editedInfo.notes
                }
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
                    TableColumn("") { photoInfo in
                        Button {
                            editingPhoto = photoInfo
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .width(40)
                    
                    TableColumn("QR Code") { photoInfo in
                        Text(qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode)
                            .font(.caption)
                    }
                    
                    TableColumn("Notes") { photoInfo in
                        Text(photoNotes[photoInfo.photoID, default: ""])
                            .font(.caption)
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
                    
                    TableColumn("Location") { photoInfo in
                        Text(photoInfo.location)
                            .font(.caption)
                    }
                    
                    TableColumn("Temp (°C)") { photoInfo in
                        Text(photoInfo.temperatureC)
                            .font(.caption)
                    }
                    
                    TableColumn("Temp (°F)") { photoInfo in
                        Text(photoInfo.temperatureF)
                            .font(.caption)
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
            
            // Fetch location data
            LocationFetcher.fetchLocation(at: location.coordinate) { locationName, address in
                if let idx = self.selectedPhotoInfos.firstIndex(where: { $0.photoID == id }) {
                    
                    // Process location: ISO3166-2-lvl4 + first part
                    let firstPart = locationName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? locationName
                    let firstPartProcessed = firstPart.replacingOccurrences(of: "County", with: "Co.")
                    let iso3166 = address?["ISO3166-2-lvl4"] as? String ?? ""
                    let processedLocation = iso3166.isEmpty ? firstPartProcessed : "\(iso3166), \(firstPartProcessed)"
                    
                    self.selectedPhotoInfos[idx].location = processedLocation
                    self.selectedPhotoInfos[idx].address = address
                }
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
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image else {
                DispatchQueue.main.async {
                    qrCodeResults[asset.localIdentifier] = ""
                }
                return
            }
            
            // Convert NSImage to CGImage for macOS
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    qrCodeResults[asset.localIdentifier] = ""
                }
                return
            }
            
            let request = VNDetectBarcodesRequest { request, error in
                DispatchQueue.main.async {
                    if let results = request.results as? [VNBarcodeObservation],
                       let firstQR = results.first(where: { $0.symbology == .QR }),
                       let qrString = firstQR.payloadStringValue {
                        qrCodeResults[asset.localIdentifier] = qrString
                        // Store detected QR code as initial manual value
                        manualQRCodes[asset.localIdentifier] = qrString
                    } else {
                        qrCodeResults[asset.localIdentifier] = ""
                    }
                    
                    // Force UI update by updating the PhotoInfo object
                    if let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == asset.localIdentifier }) {
                        selectedPhotoInfos[index].qrCode = qrCodeResults[asset.localIdentifier] ?? ""
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
            let qrCode = qrCodeResults[info.photoID] ?? info.qrCode
            let addressCodable = info.address?.mapValues { AnyCodable($0) }
            return ExportPhotoInfo(
                photoID: info.photoID,
                dateTimeOriginal: info.dateTimeOriginal,
                latitude: latitude,
                longitude: longitude,
                qrCode: qrCode.isEmpty ? nil : qrCode,
                temperatureC: tempC,
                temperatureF: tempF,
                notes: photoNotes[info.photoID] ?? "",
                location: info.location,
                address: addressCodable
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
