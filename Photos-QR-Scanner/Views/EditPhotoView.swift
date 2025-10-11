import SwiftUI
import Photos

struct PhotoInfoEdit {
    var qrCode: String
    var notes: String
}

struct EditPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photoInfo: PhotoInfo
    @State private var editedInfo: PhotoInfoEdit
    let onSave: (PhotoInfoEdit) -> Void
    @State private var previewImage: NSImage?
    
    init(photoInfo: PhotoInfo, qrCode: String, notes: String, onSave: @escaping (PhotoInfoEdit) -> Void) {
        self.photoInfo = photoInfo
        self._editedInfo = State(initialValue: PhotoInfoEdit(
            qrCode: qrCode,
            notes: notes
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