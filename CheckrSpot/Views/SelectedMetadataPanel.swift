import SwiftUI

struct SelectedMetadataPanel: View {
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager

    @Binding var selectedPhotoInfos: [PhotoInfo]
    @Binding var sortOrder: [KeyPathComparator<PhotoInfo>]

    let qrCodeResults: [String: String]
    let photoNotes: [String: String]
    let photoCollectors: [String: String]
    let photoMultiplicities: [String: Int]

    let onExportJSON: () -> Void
    let onCopyJSON: () -> Void
    let onViewLabels: () -> Void
    let onEditPhoto: (PhotoInfo) -> Void

    #if os(iOS)
    @Binding var showingLabelView: Bool
    let jsonDataProvider: () -> Data
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            Text("Selected Photos (\(selectedPhotoInfos.count))")
                .font(.headline)
                .padding()

            HStack(spacing: 12) {
                Button("Export to JSON") {
                    onExportJSON()
                }
                .disabled(selectedPhotoInfos.isEmpty)

                Button("Copy JSON") {
                    onCopyJSON()
                }
                .disabled(selectedPhotoInfos.isEmpty)

                Button("View Labels") {
                    onViewLabels()
                }
                .disabled(selectedPhotoInfos.isEmpty)
                #if os(iOS)
                .sheet(isPresented: $showingLabelView) {
                    LabelWebView(jsonDataProvider: jsonDataProvider)
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
                            onEditPhoto(photoInfo)
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
                                onEditPhoto(photoInfo)
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
}
