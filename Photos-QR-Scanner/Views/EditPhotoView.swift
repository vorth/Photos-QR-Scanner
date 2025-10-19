import SwiftUI
import Photos

struct PhotoInfoEdit {
    var qrCode: String
    var notes: String
    var collector: String
}

struct EditPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager
    let photoInfo: PhotoInfo
    @State private var editedInfo: PhotoInfoEdit
    let onSave: (PhotoInfoEdit) -> Void
    @State private var previewImage: NSImage?
    @State private var showingCollectorSuggestions = false
    
    init(photoInfo: PhotoInfo, qrCode: String, notes: String, collector: String, onSave: @escaping (PhotoInfoEdit) -> Void) {
        self.photoInfo = photoInfo
        self._editedInfo = State(initialValue: PhotoInfoEdit(
            qrCode: qrCode,
            notes: notes,
            collector: collector
        ))
        self.onSave = onSave
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Photo
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(Color(.textBackgroundColor))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(Color(.textBackgroundColor))
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
                            HStack {
                                Text("Collector")
                                    .font(.headline)
                                Spacer()
                                if !collectorManager.getAllCollectors().isEmpty {
                                    Button(action: {
                                        showingCollectorSuggestions.toggle()
                                    }) {
                                        Image(systemName: showingCollectorSuggestions ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Enter collector name", text: $editedInfo.collector)
                                    .textFieldStyle(.roundedBorder)
                                
                                if showingCollectorSuggestions && !collectorManager.getAllCollectors().isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Previous collectors:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        ScrollView {
                                            LazyVStack(alignment: .leading, spacing: 2) {
                                                ForEach(collectorManager.getAllCollectors(), id: \.self) { collector in
                                                    Button(action: {
                                                        editedInfo.collector = collector
                                                        showingCollectorSuggestions = false
                                                    }) {
                                                        HStack {
                                                            Text(collector)
                                                                .font(.system(.body, design: .monospaced))
                                                                .foregroundColor(.primary)
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color(.controlBackgroundColor))
                                                        .cornerRadius(4)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 120)
                                        .background(Color(.textBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color(.separatorColor), lineWidth: 1)
                                        )
                                    }
                                }
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
                        InfoRow(label: "Location", value: photoInfo.location)
                        InfoRow(label: "Temperature", value: "\(photoInfo.temperatureC) / \(photoInfo.temperatureF)")
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
            .background(Color(.controlBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            loadPreviewImage()
        }
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