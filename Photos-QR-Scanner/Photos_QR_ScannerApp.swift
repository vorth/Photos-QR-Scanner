import SwiftUI
import Photos
import PhotosUI

// MARK: - Main App
@main
struct PhotoMetadataApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Photo Data Model
struct PhotoInfo: Identifiable {
    let id = UUID()
    let asset: PHAsset
    let localIdentifier: String
    let dateTimeOriginal: String
    
    init(asset: PHAsset) {
        self.asset = asset
        self.localIdentifier = asset.localIdentifier
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        if let creationDate = asset.creationDate {
            self.dateTimeOriginal = formatter.string(from: creationDate)
        } else {
            self.dateTimeOriginal = "Unknown"
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var photos: [PHAsset] = []
    @State private var selectedPhotos: Set<String> = []
    @State private var selectedPhotoInfos: [PhotoInfo] = []
    
    var body: some View {
        NavigationView {
            if authorizationStatus == .authorized || authorizationStatus == .limited {
                HSplitView {
                    // Left side - Photo selection
                    VStack {
                        Text("Photos")
                            .font(.headline)
                            .padding(.top)
                        
                        if photos.isEmpty {
                            Text("Loading photos...")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 120), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(photos.indices, id: \.self) { index in
                                        PhotoThumbnailView(
                                            asset: photos[index],
                                            isSelected: selectedPhotos.contains(photos[index].localIdentifier)
                                        ) {
                                            togglePhotoSelection(photos[index])
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .frame(minWidth: 300)
                    
                    // Right side - Metadata table
                    VStack {
                        Text("Selected Photos Metadata")
                            .font(.headline)
                            .padding(.top)
                        
                        if selectedPhotoInfos.isEmpty {
                            Text("No photos selected")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Table(selectedPhotoInfos) {
                                TableColumn("Photo ID") { photoInfo in
                                    Text(String(photoInfo.localIdentifier.prefix(8)))
                                        .font(.system(.caption, design: .monospaced))
                                }
                                .width(min: 80, ideal: 120, max: 200)
                                
                                TableColumn("Date/Time Original") { photoInfo in
                                    Text(photoInfo.dateTimeOriginal)
                                        .font(.system(.caption))
                                }
                                .width(min: 150, ideal: 200)
                            }
                            .padding()
                        }
                    }
                    .frame(minWidth: 400)
                }
            } else {
                VStack(spacing: 20) {
                    Text("Photos Access Required")
                        .font(.title)
                    
                    Text("This app needs access to your Photos library to display photos and metadata.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Request Access") {
                        requestPhotosAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Photo Metadata Viewer")
        .onAppear {
            checkPhotosPermission()
        }
    }
    
    // MARK: - Photo Selection Logic
    private func togglePhotoSelection(_ asset: PHAsset) {
        if selectedPhotos.contains(asset.localIdentifier) {
            selectedPhotos.remove(asset.localIdentifier)
            selectedPhotoInfos.removeAll { $0.localIdentifier == asset.localIdentifier }
        } else {
            selectedPhotos.insert(asset.localIdentifier)
            selectedPhotoInfos.append(PhotoInfo(asset: asset))
        }
    }
    
    // MARK: - Photos Permission
    private func checkPhotosPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            loadPhotos()
        }
    }
    
    private func requestPhotosAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                if status == .authorized || status == .limited {
                    loadPhotos()
                }
            }
        }
    }
    
    // MARK: - Photo Loading
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 200 // Limit for performance
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var loadedPhotos: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            loadedPhotos.append(asset)
        }
        
        DispatchQueue.main.async {
            self.photos = loadedPhotos
        }
    }
}

// MARK: - Photo Thumbnail View
struct PhotoThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var image: Image?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .frame(width: 120, height: 120)
                }
                
                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 120, height: 120)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .padding(.top, 4)
                                .padding(.trailing, 4)
                        }
                        Spacer()
                    }
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                onTap()
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { uiImage, _ in
            DispatchQueue.main.async {
                if let uiImage = uiImage {
                  self.image = Image(nsImage: NSImage(cgImage: uiImage.cgImage, size: .zero))
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
