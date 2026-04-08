import SwiftUI
import Photos
import Vision
import CoreGraphics
import CoreLocation
import WebKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS)
typealias PlatformImage = NSImage
#elseif os(iOS)
typealias PlatformImage = UIImage
#endif

// Helper class to hold data that the server can access
class PhotoDataHolder {
    var photoInfos: [PhotoInfo] = []
    var qrCodeResults: [String: String] = [:]
    var photoNotes: [String: String] = [:]
    var photoCollectors: [String: String] = [:]
    var photoMultiplicities: [String: Int] = [:]
}

struct ContentView: View {
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
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
    
    var body: some View {
        mainView
            .navigationTitle("Photos Metadata")
            .onAppear {
                checkPermissions()
                #if os(macOS)
                startServerIfNeeded()
                #endif
            }
            #if os(macOS)
            .onDisappear {
                httpServer?.stop()
            }
            #endif
            .sheet(item: $editingPhoto) { photoInfo in
                EditPhotoView(
                    photoInfo: photoInfo,
                    qrCode: qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode,
                    notes: photoNotes[photoInfo.photoID, default: ""],
                    collector: photoCollectors[photoInfo.photoID] ?? collectorManager.lastCollector,
                    multiplicity: photoMultiplicities[photoInfo.photoID, default: 1]
                ) { editedInfo in
                    // Update the corresponding PhotoInfo in selectedPhotoInfos
                    if let index = selectedPhotoInfos.firstIndex(where: { $0.photoID == photoInfo.photoID }) {
                        selectedPhotoInfos[index].qrCode = editedInfo.qrCode
                        selectedPhotoInfos[index].notes = editedInfo.notes
                        selectedPhotoInfos[index].collector = editedInfo.collector
                        selectedPhotoInfos[index].multiplicity = editedInfo.multiplicity
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
                }
            }
    }
    
    private var mainView: some View {
        Group {
            if authStatus == .authorized || authStatus == .limited {
                #if os(macOS)
                HSplitView {
                    photoGridView
                        .frame(minWidth: 250, idealWidth: 400, maxWidth: .infinity)
                    metadataTableView
                        .frame(minWidth: 350, idealWidth: 500, maxWidth: .infinity)
                }
                #else
                TabView {
                    photoGridView
                        .tabItem {
                            Label("Photos", systemImage: "photo.on.rectangle")
                        }
                    metadataTableView
                        .tabItem {
                            Label("Selected", systemImage: "list.bullet")
                        }
                }
                #endif
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
                            qrCodeResult: qrCodeResults[asset.localIdentifier],
                            onEdit: selectedIDs.contains(asset.localIdentifier) ? {
                                // Find the corresponding PhotoInfo for this asset
                                if let photoInfo = selectedPhotoInfos.first(where: { $0.photoID == asset.localIdentifier }) {
                                    editingPhoto = photoInfo
                                }
                            } : nil
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
            
            HStack(spacing: 12) {
                Button("Export to JSON") {
                    exportSelectedPhotosToJSON()
                }
                .disabled(selectedPhotoInfos.isEmpty)
                
                Button("Copy JSON") {
                    copyJSONToClipboard()
                }
                .disabled(selectedPhotoInfos.isEmpty)
                
                Button("View Labels") {
                    #if os(macOS)
                    viewInBrowser()
                    #else
                    showingLabelView = true
                    #endif
                }
                .disabled(selectedPhotoInfos.isEmpty)
                #if os(iOS)
                .sheet(isPresented: $showingLabelView) {
                    LabelWebView(jsonDataProvider: buildExportJSONData)
                }
                #endif
            }
            .padding(.horizontal)

            if selectedPhotoInfos.isEmpty {
                Text("Select photos to view metadata")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                #if os(macOS)
                Table(selectedPhotoInfos, sortOrder: $sortOrder) {
                    TableColumn("") { photoInfo in
                        Button {
                            editingPhoto = photoInfo
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 18))
                                Text("Edit")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Edit photo information")
                    }
                    .width(70)
                    
                    TableColumn("QR Code") { photoInfo in
                        Text(qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode)
                            .font(.caption)
                    }
                    
                    TableColumn("Notes") { photoInfo in
                        Text(photoNotes[photoInfo.photoID, default: ""])
                            .font(.caption)
                    }
                    
                    TableColumn("Date/Time", value: \.dateTimeOriginal) { photoInfo in
                        Text(photoInfo.dateTimeOriginal)
                            .font(.caption)
                    }
                  
                    TableColumn("Location", value: \.location) { photoInfo in
                        Text(photoInfo.location)
                            .font(.caption)
                    }

                    TableColumn("Lat/Long", value: \.latLong) { photoInfo in
                        Text(photoInfo.latLong)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                                        
                    TableColumn("Temp (°F)", value: \.temperatureF) { photoInfo in
                        Text(photoInfo.temperatureF)
                            .font(.caption)
                    }
                  
                    TableColumn("Collector") { photoInfo in
                        Text(photoCollectors[photoInfo.photoID] ?? collectorManager.lastCollector)
                            .font(.caption)
                    }

                    TableColumn("Mult.") { photoInfo in
                        Text("\(photoMultiplicities[photoInfo.photoID, default: 1])")
                            .font(.caption)
                    }
                    .width(50)
                }
                .padding()
                .onChange(of: sortOrder) {
                    selectedPhotoInfos.sort(using: sortOrder)
                }
                #else
                List(selectedPhotoInfos) { photoInfo in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(qrCodeResults[photoInfo.photoID] ?? photoInfo.qrCode)
                                .font(.headline)
                            Spacer()
                            Button {
                                editingPhoto = photoInfo
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                            }
                        }
                        Text(photoInfo.dateTimeOriginal)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !photoInfo.location.isEmpty {
                            Text(photoInfo.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !(photoNotes[photoInfo.photoID, default: ""].isEmpty) {
                            Text(photoNotes[photoInfo.photoID, default: ""])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let mult = photoMultiplicities[photoInfo.photoID, default: 1]
                        if mult > 1 {
                            Text("Multiplicity: \(mult)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                #endif
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
            selectedIDs.remove(id)
            selectedPhotoInfos.removeAll { $0.photoID == id }
            qrCodeResults.removeValue(forKey: id)
            photoNotes.removeValue(forKey: id)
            photoCollectors.removeValue(forKey: id)
            photoMultiplicities.removeValue(forKey: id)
        } else {
            selectedIDs.insert(id)
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
                            String(format: "%.0f°C", tempC!) : "—"
                         let f = tempC != nil ? tempC! * 9.0/5.0 + 32.0 : nil
                         selectedPhotoInfos[idx].temperatureF = f != nil ?
                            String(format: "%.0f°F", f!) : "—"
                        
                        print("Historic temperature for \(id):",
                              tempC.map { "\($0)°C" } ?? "unknown")
                                            updateDataHolder()
                    }
                })
                updateDataHolder()
            }
        }
    }
    
    private func deselectPhoto(_ photoID: String) {
        selectedIDs.remove(photoID)
        selectedPhotoInfos.removeAll { $0.photoID == photoID }
        qrCodeResults.removeValue(forKey: photoID)
        photoNotes.removeValue(forKey: photoID)
        photoCollectors.removeValue(forKey: photoID)
        updateDataHolder()
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
            let latitude = latLongParts.count == 2 ? latLongParts[0] : ""
            let longitude = latLongParts.count == 2 ? latLongParts[1] : ""
            let tempC = info.temperatureC.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
            let tempF = info.temperatureF.replacingOccurrences(of: "°F", with: "").trimmingCharacters(in: .whitespaces)
            let temperature = "\(info.temperatureC)/\(info.temperatureF)"
            let qrCode = qrCodeResults[info.photoID] ?? info.qrCode
            let addressCodable = info.address?.mapValues { AnyCodable($0) }
            return ExportPhotoInfo(
                photoID: info.photoID,
                dateTimeOriginal: info.dateTimeOriginal,
                latitude: latitude,
                longitude: longitude,
                elevation: info.elevation,
                qrCode: qrCode.isEmpty ? nil : qrCode,
                temperature: temperature,
                temperatureC: tempC,
                temperatureF: tempF,
                notes: photoNotes[info.photoID] ?? "",
                collector: photoCollectors[info.photoID] ?? collectorManager.lastCollector,
                multiplicity: photoMultiplicities[info.photoID] ?? 1,
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
                return jsonString
            }
        } catch {
            print("JSON encoding failed: \(error)")
        }
        return nil
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

    #if os(macOS)
    private func startServerIfNeeded() {
        guard httpServer == nil else { return }
        
        print("ContentView: Starting HTTP server")
        updateDataHolder()
        
        let jsonDataProvider: () -> Data = { [dataHolder] in
            print("HTTPServer: Generating fresh JSON from current data")
            let exportData = dataHolder.photoInfos.map { info in
                let latLongParts = info.latLong.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let latitude = latLongParts.count == 2 ? latLongParts[0] : ""
                let longitude = latLongParts.count == 2 ? latLongParts[1] : ""
                let tempC = info.temperatureC.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
                let tempF = info.temperatureF.replacingOccurrences(of: "°F", with: "").trimmingCharacters(in: .whitespaces)
                let temperature = "\(info.temperatureC)/\(info.temperatureF)"
                let qrCode = dataHolder.qrCodeResults[info.photoID] ?? info.qrCode
                let addressCodable = info.address?.mapValues { AnyCodable($0) }
                return ExportPhotoInfo(
                    photoID: info.photoID,
                    dateTimeOriginal: info.dateTimeOriginal,
                    latitude: latitude,
                    longitude: longitude,
                    elevation: info.elevation,
                    qrCode: qrCode.isEmpty ? nil : qrCode,
                    temperature: temperature,
                    temperatureC: tempC,
                    temperatureF: tempF,
                    notes: dataHolder.photoNotes[info.photoID] ?? "",
                    collector: dataHolder.photoCollectors[info.photoID] ?? "",
                    multiplicity: dataHolder.photoMultiplicities[info.photoID] ?? 1,
                    location: info.location,
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

// MARK: - WKWebView-based Label Viewer (iOS)

#if os(iOS)
struct LabelWebView: View {
    @Environment(\.dismiss) private var dismiss
    let jsonDataProvider: () -> Data
    @State private var webView: WKWebView?
    @State private var printStatus: String?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LabelWebViewRepresentable(jsonDataProvider: jsonDataProvider, webViewRef: $webView)
                if let status = printStatus {
                    Text(status)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: printStatus)
            .navigationTitle("Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        printLabels()
                    } label: {
                        Image(systemName: "printer")
                    }
                }
            }
        }
    }
    
    private func printLabels() {
        guard let webView else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Specimen Labels"
        printInfo.outputType = .general
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true) { _, completed, error in
            DispatchQueue.main.async {
                if completed {
                    printStatus = "Print job sent"
                } else if let error {
                    printStatus = "Print failed: \(error.localizedDescription)"
                } else {
                    printStatus = "Print cancelled"
                }
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    printStatus = nil
                }
            }
        }
    }
}

struct LabelWebViewRepresentable: UIViewRepresentable {
    let jsonDataProvider: () -> Data
    @Binding var webViewRef: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        DispatchQueue.main.async { webViewRef = webView }
        loadContent(into: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    private func loadContent(into webView: WKWebView) {
        guard let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html"),
              var htmlString = try? String(contentsOf: htmlURL, encoding: .utf8) else {
            return
        }
        
        // Inline the CSS (match the leading slash in href="/styles.css")
        if let cssURL = Bundle.main.url(forResource: "styles", withExtension: "css"),
           let css = try? String(contentsOf: cssURL, encoding: .utf8) {
            htmlString = htmlString.replacingOccurrences(
                of: "<link rel=\"stylesheet\" href=\"/styles.css\">",
                with: "<style>\(css)</style>"
            )
        }
        
        // Inline the JS, replacing the fetch() call with embedded JSON data
        if let jsURL = Bundle.main.url(forResource: "script", withExtension: "js"),
           var js = try? String(contentsOf: jsURL, encoding: .utf8) {
            let jsonData = jsonDataProvider()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            let inlineDataScript = "window.__specimensData = \(jsonString);\n"
            js = js.replacingOccurrences(
                of: "fetch('/specimens.json')",
                with: "Promise.resolve({ ok: true, json: () => Promise.resolve(window.__specimensData) })"
            )
            
            // Match the actual script tag: <script type="module" src="/script.js">
            htmlString = htmlString.replacingOccurrences(
                of: "<script type=\"module\" src=\"/script.js\"></script>",
                with: "<script type=\"module\">\(inlineDataScript)\(js)</script>"
            )
        }
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}
#endif
