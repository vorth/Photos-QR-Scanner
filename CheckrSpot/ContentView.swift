import SwiftUI
import Photos
import Vision
import CoreGraphics
import CoreLocation
import UniformTypeIdentifiers
import ImageIO
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
    @State private var lastSelectedID: String? = nil
    @State private var selectedPhotoInfos: [PhotoInfo] = []
    @State private var qrCodeResults: [String: String] = [:]
    @State private var thumbnailSize: Double = 100
    @State private var photoNotes: [String: String] = [:]
    @State private var photoCollectors: [String: String] = [:]
    @State private var photoMultiplicities: [String: Int] = [:]
    @State private var manualQRCodes: [String: String] = [:]
    @State private var editingPhoto: PhotoInfo? = nil
    @State private var sortOrder: [KeyPathComparator<PhotoInfo>] = [KeyPathComparator(\.dateTimeOriginal, order: .forward)]
    #if os(macOS)
    @State private var httpServer: HTTPServer?
    @State private var isServerRunning: Bool = false
    #endif
    @State private var showingLabelView: Bool = false
    @State private var dataHolder = PhotoDataHolder()
    #if os(iOS)
    @State private var selectedBottomTab: IOSBottomBarView.BottomTab = .photos
    @State private var showingCameraPicker: Bool = false
    @State private var cameraSourceType: UIImagePickerController.SourceType = .camera
    @State private var showingNoCameraAlert: Bool = false
    @StateObject private var locationStatus = IOSLocationStatusMonitor()
    #endif
    
    var body: some View {
        mainView
            .navigationTitle("Photos Metadata")
            .onAppear {
                checkPermissions()
                #if os(macOS)
                startServerIfNeeded()
                #elseif os(iOS)
                locationStatus.startUpdating()
                #endif
            }
            #if os(macOS)
            .onDisappear {
                httpServer?.stop()
            }
            #endif
            #if os(iOS)
            .onDisappear {
                locationStatus.stopUpdating()
            }
            #endif
            .sheet(item: $editingPhoto) { photoInfo in
                EditPhotoView(
                    photoInfo: photoInfo,
                    allSpecimens: selectedPhotoInfos,
                    qrCodeResults: qrCodeResults,
                    qrCode: qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode,
                    notes: photoNotes[photoInfo.photoID, default: ""],
                    collector: photoCollectors[photoInfo.photoID] ?? collectorManager.lastCollector,
                    multiplicity: photoMultiplicities[photoInfo.photoID, default: 1]
                ) { editedInfo in
                    // Update the corresponding PhotoInfo in selectedPhotoInfos
                    if let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == photoInfo.photoID }) {
                        let previousLatLong = selectedPhotoInfos[index].latLong
                        selectedPhotoInfos[index].qrCode = editedInfo.qrCode
                        selectedPhotoInfos[index].notes = editedInfo.notes
                        selectedPhotoInfos[index].collector = editedInfo.collector
                        selectedPhotoInfos[index].multiplicity = editedInfo.multiplicity
                        selectedPhotoInfos[index].latLong = editedInfo.latLong
                        selectedPhotoInfos[index].location = editedInfo.location
                        selectedPhotoInfos[index].address = editedInfo.address
                        selectedPhotoInfos[index].temperatureC = editedInfo.temperatureC
                        selectedPhotoInfos[index].temperatureF = editedInfo.temperatureF

                        if editedInfo.latLong != previousLatLong,
                           let coordinate = parseCoordinate(from: editedInfo.latLong) {
                            refreshMetadataForEditedCoordinate(photoID: photoInfo.photoID, coordinate: coordinate)
                        }
                    }
                    
                    // Update QR code result, notes, and collector immediately
                    qrCodeResults[photoInfo.photoID] = editedInfo.qrCode
                    photoNotes[photoInfo.photoID] = editedInfo.notes
                    photoCollectors[photoInfo.photoID] = editedInfo.collector
                    photoMultiplicities[photoInfo.photoID] = editedInfo.multiplicity
                    
                    // Update data holder for server
                    updateDataHolder()
                    
                    // Save the collector value to preferences if it's not empty
                    if !editedInfo.collector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        collectorManager.addCollector(editedInfo.collector)
                    }
                } onDeselect: {
                    deselectPhoto(photoInfo.photoID)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingCameraPicker) {
                CameraPickerRepresentable(sourceType: cameraSourceType) { image, metadata in
                    saveCapturedImageToPhotoLibrary(image, metadata: metadata)
                }
                .ignoresSafeArea()
            }
            .alert("Camera Unavailable", isPresented: $showingNoCameraAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This device does not have an available camera.")
            }
            #endif
    }
    
    private var mainView: some View {
        Group {
            if authStatus == .authorized || authStatus == .limited {
                #if os(macOS)
                HSplitView {
                    PhotoGridPanel(
                        allPhotos: allPhotos,
                        selectedIDs: selectedIDs,
                        thumbnailSize: $thumbnailSize,
                        qrCodeResults: qrCodeResults,
                        scrollTargetPhotoID: scrollTargetPhotoID,
                        onToggleSelection: toggleSelection,
                        onEditSelectedPhoto: beginEditingPhoto
                    )
                        .frame(minWidth: 250, idealWidth: 400, maxWidth: .infinity)
                    SelectedMetadataPanel(
                        selectedPhotoInfos: $selectedPhotoInfos,
                        sortOrder: $sortOrder,
                        qrCodeResults: qrCodeResults,
                        photoNotes: photoNotes,
                        photoCollectors: photoCollectors,
                        photoMultiplicities: photoMultiplicities,
                        onExportJSON: exportSelectedPhotosToJSON,
                        onCopyJSON: copyJSONToClipboard,
                        onViewLabels: viewInBrowser,
                        onEditPhoto: { editingPhoto = $0 }
                    )
                    .environmentObject(collectorManager)
                        .frame(minWidth: 350, idealWidth: 500, maxWidth: .infinity)
                }
                #else
                VStack(spacing: 0) {
                    Group {
                        switch selectedBottomTab {
                        case .photos:
                            PhotoGridPanel(
                                allPhotos: allPhotos,
                                selectedIDs: selectedIDs,
                                thumbnailSize: $thumbnailSize,
                                qrCodeResults: qrCodeResults,
                                scrollTargetPhotoID: scrollTargetPhotoID,
                                onToggleSelection: toggleSelection,
                                onEditSelectedPhoto: beginEditingPhoto
                            )
                        case .selected:
                            SelectedMetadataPanel(
                                selectedPhotoInfos: $selectedPhotoInfos,
                                sortOrder: $sortOrder,
                                qrCodeResults: qrCodeResults,
                                photoNotes: photoNotes,
                                photoCollectors: photoCollectors,
                                photoMultiplicities: photoMultiplicities,
                                onExportJSON: exportSelectedPhotosToJSON,
                                onCopyJSON: copyJSONToClipboard,
                                onViewLabels: { showingLabelView = true },
                                onEditPhoto: { editingPhoto = $0 },
                                showingLabelView: $showingLabelView,
                                jsonDataProvider: buildExportJSONData
                            )
                            .environmentObject(collectorManager)
                        }
                    }
                    Divider()
                    IOSBottomBarView(
                        selectedBottomTab: $selectedBottomTab,
                        hasPreciseLocationFix: locationStatus.hasPreciseFix,
                        onOpenCamera: presentCameraPicker
                    )
                }
                #endif
            } else {
                PhotosPermissionView(onRequestAccess: requestAccess)
            }
        }
    }

    /// The photo the grid should scroll to when it appears. Prefers the most
    /// recently selected photo; if there isn't one still selected (fresh launch,
    /// or it was deselected) falls back to the selected photo with the latest
    /// timestamp. `allPhotos` is newest-first, so that's the first selected
    /// asset in the array. Nil when nothing is selected, leaving the grid at the
    /// top showing the newest photos.
    private var scrollTargetPhotoID: String? {
        if let lastSelectedID, selectedIDs.contains(lastSelectedID) {
            return lastSelectedID
        }
        return allPhotos.first { selectedIDs.contains($0.localIdentifier) }?.localIdentifier
    }

    private func beginEditingPhoto(asset: PHAsset) {
        if let photoInfo = selectedPhotoInfos.first(where: { $0.photoID == asset.localIdentifier }) {
            editingPhoto = photoInfo
        }
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
        options.fetchLimit = 2000
        
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
            deselectPhoto(id)
        } else {
            selectedIDs.insert(id)
            lastSelectedID = id
            let photoInfo = PhotoInfo(asset: asset)
            selectedPhotoInfos.append(photoInfo)
            selectedPhotoInfos.sort(using: sortOrder)
            
            // Default collector to last-used value
            if photoCollectors[id] == nil && !collectorManager.lastCollector.isEmpty {
                photoCollectors[id] = collectorManager.lastCollector
            }
            
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
                                    self.updateDataHolder()
                }
            }
    
            WeatherFetcher.fetchHistoricTemp(at: location.coordinate,
                                             on: creation) { tempC in
                DispatchQueue.main.async(execute: {
                    if let idx = selectedPhotoInfos.firstIndex(where: { $0.photoID == id }) {
                         selectedPhotoInfos[idx].temperatureC = tempC != nil ?
                                     String(format: "%.0f°C", tempC!) : ""
                         let f = tempC != nil ? tempC! * 9.0/5.0 + 32.0 : nil
                         selectedPhotoInfos[idx].temperatureF = f != nil ?
                                     String(format: "%.0f°F", f!) : ""
                        
                        print("Historic temperature for \(id):",
                              tempC.map { "\($0)°C" } ?? "unknown")
                                            updateDataHolder()
                    }
                })
                updateDataHolder()
            }
        }
    }
    
    /// Single path for dropping a photo from the selection, used by both the
    /// grid's toggle and the Deselect button in the edit sheet.
    private func deselectPhoto(_ photoID: String) {
        selectedIDs.remove(photoID)
        if lastSelectedID == photoID {
            lastSelectedID = nil
        }
        selectedPhotoInfos.removeAll { $0.photoID == photoID }
        qrCodeResults.removeValue(forKey: photoID)
        photoNotes.removeValue(forKey: photoID)
        photoCollectors.removeValue(forKey: photoID)
        photoMultiplicities.removeValue(forKey: photoID)
        updateDataHolder()
    }
    
    private func detectQRCode(for asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        // Photos that have been offloaded by iCloud "Optimize Storage" only
        // have a low-resolution thumbnail on device, which is never sharp
        // enough to decode a QR code. Allow the original to be downloaded.
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            // A high-quality request calls back more than once: a degraded
            // placeholder first, then the real image. Ignore the placeholder so
            // a blurry thumbnail cannot produce (or overwrite) a QR result.
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if isDegraded { return }

            guard let image = image else {
                DispatchQueue.main.async {
                    qrCodeResults[asset.localIdentifier] = ""
                }
                return
            }
            
            // Convert platform image to CGImage
            let cgImage: CGImage?
            #if os(macOS)
            cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            #else
            cgImage = image.cgImage
            #endif
            guard let cgImage else {
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
                                        updateDataHolder()
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func buildExportJSON() -> String? {
        let exportData = selectedPhotoInfos.map { info in
            let latLongParts = info.latLong.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let latitude = latLongParts.count == 2 ? String(latLongParts[0]) : nil
            let longitude = latLongParts.count == 2 ? String(latLongParts[1]) : nil
            let tempC = info.temperatureC.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
            let tempF = info.temperatureF.replacingOccurrences(of: "°F", with: "").trimmingCharacters(in: .whitespaces)
            let temperature: String? = (tempC.isEmpty || tempF.isEmpty) ? nil : "\(tempC)/\(tempF)"
            let qrCode = qrCodeResults[info.photoID] ?? info.qrCode
            let addressCodable = info.address?.mapValues { AnyCodable($0) }
            let elevation = info.elevation.trimmingCharacters(in: .whitespacesAndNewlines)
            let location = info.location.trimmingCharacters(in: .whitespacesAndNewlines)
            return ExportPhotoInfo(
                photoID: info.photoID,
                dateTimeOriginal: info.dateTimeOriginal,
                latitude: latitude,
                longitude: longitude,
                elevation: elevation.isEmpty ? nil : elevation,
                qrCode: qrCode.isEmpty ? nil : qrCode,
                temperature: temperature,
                temperatureC: tempC.isEmpty ? nil : tempC,
                temperatureF: tempF.isEmpty ? nil : tempF,
                notes: photoNotes[info.photoID] ?? "",
                collector: photoCollectors[info.photoID] ?? collectorManager.lastCollector,
                multiplicity: photoMultiplicities[info.photoID] ?? 1,
                location: location.isEmpty ? nil : location,
                address: addressCodable
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(exportData)
            if var jsonString = String(data: data, encoding: .utf8) {
                jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
                return jsonString
            }
        } catch {
            print("JSON encoding failed: \(error)")
        }
        return nil
    }

    private func parseCoordinate(from latLong: String) -> CLLocationCoordinate2D? {
        let parts = latLong
            .split(separator: ",", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]),
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func refreshMetadataForEditedCoordinate(photoID: String, coordinate: CLLocationCoordinate2D) {
        LocationFetcher.fetchLocation(at: coordinate) { locationName, address in
            if let idx = self.selectedPhotoInfos.firstIndex(where: { $0.photoID == photoID }) {
                let firstPart = locationName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? locationName
                let firstPartProcessed = firstPart.replacingOccurrences(of: "County", with: "Co.")
                let iso3166 = address?["ISO3166-2-lvl4"] as? String ?? ""
                let processedLocation = iso3166.isEmpty ? firstPartProcessed : "\(iso3166), \(firstPartProcessed)"

                self.selectedPhotoInfos[idx].location = processedLocation
                self.selectedPhotoInfos[idx].address = address
                self.updateDataHolder()
            }
        }

        guard let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == photoID }),
              let creationDate = selectedPhotoInfos[index].asset.creationDate else {
            return
        }

        WeatherFetcher.fetchHistoricTemp(at: coordinate, on: creationDate) { tempC in
            DispatchQueue.main.async {
                if let idx = selectedPhotoInfos.firstIndex(where: { $0.photoID == photoID }) {
                    selectedPhotoInfos[idx].temperatureC = tempC != nil ? String(format: "%.0f°C", tempC!) : ""
                    let f = tempC != nil ? tempC! * 9.0 / 5.0 + 32.0 : nil
                    selectedPhotoInfos[idx].temperatureF = f != nil ? String(format: "%.0f°F", f!) : ""
                    updateDataHolder()
                }
            }
        }
    }

    private func copyJSONToClipboard() {
        guard let jsonString = buildExportJSON() else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(jsonString, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = jsonString
        #endif
    }

    private func exportSelectedPhotosToJSON() {
        guard let jsonString = buildExportJSON() else { return }
        
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "photo_scan_metadata.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try jsonString.write(to: url, atomically: true, encoding: .utf8)
                print("Exported to \(url.path)")
            } catch {
                print("Export failed: \(error)")
            }
        }
        #elseif os(iOS)
        // Write to a temp file and present share sheet
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("photo_scan_metadata.json")
        do {
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let rootVC = window.rootViewController else { return }
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            }
            rootVC.present(activityVC, animated: true)
        } catch {
            print("Export failed: \(error)")
        }
        #endif
    }

    private func buildExportJSONData() -> Data {
        guard let jsonString = buildExportJSON(),
              let data = jsonString.data(using: .utf8) else {
            return Data()
        }
        return data
    }

    private func updateDataHolder() {
        dataHolder.photoInfos = selectedPhotoInfos
        dataHolder.qrCodeResults = qrCodeResults
        dataHolder.photoNotes = photoNotes
        dataHolder.photoCollectors = photoCollectors
        dataHolder.photoMultiplicities = photoMultiplicities
    }

    #if os(iOS)
    private func presentCameraPicker() {
        locationStatus.requestLocationUpdate()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            cameraSourceType = .camera
            showingCameraPicker = true
        } else {
            showingNoCameraAlert = true
        }
    }

    private func saveCapturedImageToPhotoLibrary(_ image: UIImage, metadata: [String: Any]) {
        // UIImage-only saves drop EXIF/GPS, so re-encode with metadata and add GPS explicitly.
        if let imageData = buildJPEGDataWithMetadata(for: image, baseMetadata: metadata) {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, error in
                if let error {
                    print("Failed to save captured photo with metadata: \(error.localizedDescription)")
                }
                if success {
                    DispatchQueue.main.async {
                        refreshRecentPhotosAfterCapture()
                    }
                }
            }
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if let error {
                print("Failed to save captured photo: \(error.localizedDescription)")
            }
            if success {
                DispatchQueue.main.async {
                    refreshRecentPhotosAfterCapture()
                }
            }
        }
    }

    private func refreshRecentPhotosAfterCapture() {
        // Photos indexing can lag briefly after capture, so refresh a few times.
        loadRecentPhotos()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            loadRecentPhotos()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentPhotos()
        }
    }

    private func buildJPEGDataWithMetadata(for image: UIImage, baseMetadata: [String: Any]) -> Data? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        var finalMetadata = baseMetadata
        // Always remove incoming GPS tags and re-add only when app authorization allows it.
        finalMetadata.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        if locationStatus.canAttachGPS, let location = locationStatus.latestLocation {
            finalMetadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata(from: location)
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, finalMetadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }

    private func gpsMetadata(from location: CLLocation) -> [String: Any] {
        let coordinate = location.coordinate
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss.SSSSSS"

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy:MM:dd"

        return [
            kCGImagePropertyGPSLatitude as String: abs(coordinate.latitude),
            kCGImagePropertyGPSLatitudeRef as String: coordinate.latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(coordinate.longitude),
            kCGImagePropertyGPSLongitudeRef as String: coordinate.longitude >= 0 ? "E" : "W",
            kCGImagePropertyGPSAltitude as String: location.altitude,
            kCGImagePropertyGPSAltitudeRef as String: location.altitude >= 0 ? 0 : 1,
            kCGImagePropertyGPSTimeStamp as String: formatter.string(from: location.timestamp),
            kCGImagePropertyGPSDateStamp as String: dateFormatter.string(from: location.timestamp),
            kCGImagePropertyGPSDOP as String: max(location.horizontalAccuracy, 0)
        ]
    }
    #endif

    #if os(macOS)
    private func startServerIfNeeded() {
        guard httpServer == nil else { return }
        
        print("ContentView: Starting HTTP server")
        updateDataHolder()
        
        let jsonDataProvider: () -> Data = { [dataHolder] in
            print("HTTPServer: Generating fresh JSON from current data")
            let exportData = dataHolder.photoInfos.map { info in
                let latLongParts = info.latLong.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let latitude = latLongParts.count == 2 ? String(latLongParts[0]) : nil
                let longitude = latLongParts.count == 2 ? String(latLongParts[1]) : nil
                let tempC = info.temperatureC.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
                let tempF = info.temperatureF.replacingOccurrences(of: "°F", with: "").trimmingCharacters(in: .whitespaces)
                let temperature: String? = (tempC.isEmpty || tempF.isEmpty) ? nil : "\(tempC)/\(tempF)"
                let qrCode = dataHolder.qrCodeResults[info.photoID] ?? info.qrCode
                let addressCodable = info.address?.mapValues { AnyCodable($0) }
                let elevation = info.elevation.trimmingCharacters(in: .whitespacesAndNewlines)
                let location = info.location.trimmingCharacters(in: .whitespacesAndNewlines)
                return ExportPhotoInfo(
                    photoID: info.photoID,
                    dateTimeOriginal: info.dateTimeOriginal,
                    latitude: latitude,
                    longitude: longitude,
                    elevation: elevation.isEmpty ? nil : elevation,
                    qrCode: qrCode.isEmpty ? nil : qrCode,
                    temperature: temperature,
                    temperatureC: tempC.isEmpty ? nil : tempC,
                    temperatureF: tempF.isEmpty ? nil : tempF,
                    notes: dataHolder.photoNotes[info.photoID] ?? "",
                    collector: dataHolder.photoCollectors[info.photoID] ?? "",
                    multiplicity: dataHolder.photoMultiplicities[info.photoID] ?? 1,
                    location: location.isEmpty ? nil : location,
                    address: addressCodable
                )
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            do {
                let jsonData = try encoder.encode(exportData)
                return jsonData
            } catch {
                print("Failed to encode JSON: \(error)")
                return Data()
            }
        }
        
        let server = HTTPServer(port: 8000)
        self.httpServer = server
        
        Task {
            do {
                let url = try await server.startServer(with: jsonDataProvider)
                print("Server started at \(url)")
                
                DispatchQueue.main.async {
                    self.isServerRunning = true
                }
            } catch {
                print("Failed to start server: \(error)")
                DispatchQueue.main.async {
                    self.isServerRunning = false
                }
            }
        }
    }
    
    private func viewInBrowser() {
        print("ContentView: viewInBrowser() called")
        
        if isServerRunning {
            let url = URL(string: "http://localhost:8000")!
            NSWorkspace.shared.open(url)
        } else {
            print("Server not running yet")
        }
    }
    #endif
}
