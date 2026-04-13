import SwiftUI
import Photos
#if os(macOS)
import AppKit
#endif

struct PhotoInfoEdit {
    var qrCode: String
    var notes: String
    var collector: String
    var multiplicity: Int
}

struct EditPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager
    let photoInfo: PhotoInfo
    @State private var editedInfo: PhotoInfoEdit
    let onSave: (PhotoInfoEdit) -> Void
    @State private var previewImage: PlatformImage?
    
    init(photoInfo: PhotoInfo, qrCode: String, notes: String, collector: String, multiplicity: Int, onSave: @escaping (PhotoInfoEdit) -> Void) {
        self.photoInfo = photoInfo
        self._editedInfo = State(initialValue: PhotoInfoEdit(
            qrCode: qrCode,
            notes: notes,
            collector: collector,
            multiplicity: multiplicity
        ))
        self.onSave = onSave
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Photo
            if let image = previewImage {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(photoBackground)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(photoBackground)
            }
            
            // Right side - Form
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        VStack(alignment: .leading) {
                            Text("QR Code")
                                .font(.headline)
                            TextField("Enter QR code", text: $editedInfo.qrCode)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Collector")
                                .font(.headline)
                            HStack {
                                TextField("Enter collector name", text: $editedInfo.collector)
                                    .textFieldStyle(.roundedBorder)
                                if !collectorManager.getAllCollectors().isEmpty {
                                    Menu {
                                        ForEach(collectorManager.getAllCollectors(), id: \.self) { collector in
                                            Button(collector) {
                                                editedInfo.collector = collector
                                            }
                                        }
                                    } label: {
                                        EmptyView()
                                    }
                                    #if os(macOS)
                                    .menuStyle(.borderlessButton)
                                    #endif
                                    .fixedSize()
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Multiplicity")
                                .font(.headline)
                            Stepper(value: $editedInfo.multiplicity, in: 1...Int.max) {
                                TextField("", value: $editedInfo.multiplicity, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Notes")
                                .font(.headline)
                            TextField("Notes", text: $editedInfo.notes)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    Group {
                        InfoRow(label: "Date/Time", value: photoInfo.dateTimeOriginal)
                        InfoRow(label: "Lat/Long", value: photoInfo.latLong)
                        InfoRow(label: "Elevation", value: photoInfo.elevation)
                        InfoRow(label: "Location", value: photoInfo.location)
                        InfoRow(label: "Temperature", value: "\(photoInfo.temperatureC)/\(photoInfo.temperatureF)")
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Save") {
                            onSave(editedInfo)
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding()
            }
            .frame(width: 350)
            .background(formBackground)
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 500)
        #endif
        .onAppear {
            loadPreviewImage()
        }
    }
    
    private var photoBackground: Color {
        #if os(macOS)
        Color(.textBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
    
    private var formBackground: Color {
        #if os(macOS)
        Color(.controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }
    
    private func platformImage(_ image: PlatformImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }
    
    private func loadPreviewImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        
        manager.requestImage(
            for: photoInfo.asset,
            targetSize: CGSize(width: 2048, height: 2048),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.previewImage = image
                }
            }
        }
    }
}