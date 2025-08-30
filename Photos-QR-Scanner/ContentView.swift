import SwiftUI
import Photos
import Vision

struct PhotoMetadataApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct PhotoInfo: Identifiable {
    let id = UUID()
    let photoID: String
    let dateTimeOriginal: String
    let latLong: String
    var qrCode: String
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
    }
}

struct ContentView: View {
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedIDs: Set<String> = []
    @State private var selectedPhotoInfos: [PhotoInfo] = []
    @State private var qrCodeResults: [String: String] = [:]
    
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
            Text("Recent Photos (\(allPhotos.count))")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 6)
                ], spacing: 6) {
                    ForEach(allPhotos.indices, id: \.self) { index in
                        ThumbnailView(
                            asset: allPhotos[index],
                            isSelected: selectedIDs.contains(allPhotos[index].localIdentifier)
                        ) {
                            toggleSelection(allPhotos[index])
                        }
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
        } else {
            selectedIDs.insert(id)
            let photoInfo = PhotoInfo(asset: asset)
            selectedPhotoInfos.append(photoInfo)
            
            // Start QR code detection for newly selected photo
            detectQRCode(for: asset)
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
}

struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 100, height: 100)
            
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            
            if isSelected {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        
        // Account for Retina displays - request 2x or 3x the display size
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let targetSize = CGSize(width: 100 * scale, height: 100 * scale)
        
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
