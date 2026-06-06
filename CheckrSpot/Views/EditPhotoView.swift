import SwiftUI
import Photos
import CoreLocation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct PhotoInfoEdit {
    var qrCode: String
    var notes: String
    var collector: String
    var multiplicity: Int
    var latLong: String
    var temperatureC: String
    var temperatureF: String
    var location: String
    var address: [String: Any]?
}

struct EditPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectorManager: CollectorPreferencesManager
    let photoInfo: PhotoInfo
    let allSpecimens: [PhotoInfo]
    let qrCodeResults: [String: String]
    @State private var editedInfo: PhotoInfoEdit
    let onSave: (PhotoInfoEdit) -> Void
    @State private var previewImage: PlatformImage?
    @State private var originalCoordinate: CLLocationCoordinate2D?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isEditingGPS: Bool = false
    @State private var displayedTemperatureC: String
    @State private var displayedTemperatureF: String
    @State private var displayedLocation: String
    @State private var displayedAddress: [String: Any]?
    @State private var displayedElevation: String
    
    init(
        photoInfo: PhotoInfo,
        allSpecimens: [PhotoInfo],
        qrCodeResults: [String: String],
        qrCode: String,
        notes: String,
        collector: String,
        multiplicity: Int,
        onSave: @escaping (PhotoInfoEdit) -> Void
    ) {
        self.photoInfo = photoInfo
        self.allSpecimens = allSpecimens
        self.qrCodeResults = qrCodeResults
        let parsedCoordinate = Self.parseCoordinate(from: photoInfo.latLong)
        self._editedInfo = State(initialValue: PhotoInfoEdit(
            qrCode: qrCode,
            notes: notes,
            collector: collector,
            multiplicity: multiplicity,
            latLong: photoInfo.latLong,
            temperatureC: photoInfo.temperatureC,
            temperatureF: photoInfo.temperatureF,
            location: photoInfo.location,
            address: photoInfo.address
        ))
        self._originalCoordinate = State(initialValue: parsedCoordinate)
        self._selectedCoordinate = State(initialValue: nil)
        self._displayedTemperatureC = State(initialValue: photoInfo.temperatureC)
        self._displayedTemperatureF = State(initialValue: photoInfo.temperatureF)
        self._displayedLocation = State(initialValue: photoInfo.location)
        self._displayedAddress = State(initialValue: photoInfo.address)
        self._displayedElevation = State(initialValue: photoInfo.elevation)
        self.onSave = onSave
    }
    
    var body: some View {
        Group {
            #if os(iOS)
            formView
            #else
            HStack(spacing: 0) {
                photoPreviewView
                formView
                    .frame(width: 350)
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 500)
        #endif
        .onAppear {
            loadPreviewImage()
        }
    }

    private var photoPreviewView: some View {
        #if os(iOS)
        ZStack {
            photoBackground

            if let image = previewImage {
                platformImage(image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
            }
        }
        .frame(width: iOSSquarePreviewSide, height: iOSSquarePreviewSide)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        #else
        Group {
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
        }
        #endif
    }

    #if os(iOS)
    private var iOSSquarePreviewSide: CGFloat {
        let horizontalPadding: CGFloat = 32 // Matches formView VStack padding.
        return max(160, UIScreen.main.bounds.width - horizontalPadding)
    }
    #endif

    private var formView: some View {
        ScrollView {
            VStack(spacing: 20) {
                #if os(iOS)
                photoPreviewView
                #endif

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
                    HStack(spacing: 8) {
                        Text("Lat/Long")
                            .font(.headline)
                            .frame(width: 100, alignment: .leading)

                        Text(displayedLatLong)
                            .font(.body)
                            .textSelection(.enabled)

                        Spacer(minLength: 0)

                        #if os(iOS)
                        Button {
                            beginGPSEditing()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit GPS coordinates")
                        #endif
                    }
                    .frame(maxWidth: 400, alignment: .leading)

                    #if os(iOS)
                    if isEditingGPS {
                        gpsEditorView
                    }
                    #endif

                    InfoRow(label: "Elevation", value: displayedElevation)
                    InfoRow(label: "Location", value: displayedLocation)
                    InfoRow(label: "Temperature", value: "\(displayedTemperatureC)/\(displayedTemperatureF)")
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
        .background(formBackground)
    }

    #if os(iOS)
    private var gpsEditorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            TapCoordinateMapView(
                originalCoordinate: originalCoordinate,
                selectedCoordinate: $selectedCoordinate,
                specimenPins: specimenPins
            )
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            HStack(spacing: 14) {
                Label("Original", systemImage: "circle.fill")
                    .foregroundStyle(.red)
                Label("New", systemImage: "circle.fill")
                    .foregroundStyle(.blue)
                Label("Other Specimens", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.caption)

            Text("Tap the map to choose a new coordinate.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    cancelGPSEditing()
                }

                Spacer()

                Button("Accept") {
                    acceptGPSEditing()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    #endif
    
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

    private static func parseCoordinate(from latLong: String) -> CLLocationCoordinate2D? {
        let parts = latLong.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]),
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private var displayedLatLong: String {
        if isEditingGPS, let selectedCoordinate {
            return Self.formatCoordinate(selectedCoordinate)
        }
        return editedInfo.latLong
    }

    private func beginGPSEditing() {
        selectedCoordinate = Self.parseCoordinate(from: editedInfo.latLong)
        isEditingGPS = true
    }

    private var specimenPins: [SpecimenMapPin] {
        allSpecimens
            .filter { $0.photoID != photoInfo.photoID }
            .compactMap { specimen in
                guard let coordinate = Self.parseCoordinate(from: specimen.latLong) else {
                    return nil
                }

                let qrRaw = qrCodeResults[specimen.photoID] ?? specimen.qrCode
                let qrDisplay = qrRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(no-qr)" : qrRaw
                let timeDisplay = Self.timeLabel(from: specimen.dateTimeOriginal)

                return SpecimenMapPin(
                    coordinate: coordinate,
                    qrCode: qrDisplay,
                    time: timeDisplay
                )
            }
    }

    private static func timeLabel(from dateTimeOriginal: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.locale = Locale(identifier: "en_US_POSIX")
        inFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let date = inFormatter.date(from: dateTimeOriginal) {
            let outFormatter = DateFormatter()
            outFormatter.locale = Locale(identifier: "en_US_POSIX")
            outFormatter.dateFormat = "HH:mm"
            return outFormatter.string(from: date)
        }

        // Fallback for unexpected formats while keeping hh:mm output contract.
        if let timePart = dateTimeOriginal.split(separator: " ").last {
            return String(timePart.prefix(5))
        }

        return "--:--"
    }

    private func cancelGPSEditing() {
        selectedCoordinate = nil
        isEditingGPS = false
    }

    private func acceptGPSEditing() {
        guard let selectedCoordinate else {
            isEditingGPS = false
            return
        }

        let newLatLong = Self.formatCoordinate(selectedCoordinate)
        editedInfo.latLong = newLatLong
        refreshDerivedMetadata(for: selectedCoordinate)

        isEditingGPS = false
    }

    private func refreshDerivedMetadata(for coordinate: CLLocationCoordinate2D) {
        LocationFetcher.fetchLocation(at: coordinate) { locationName, address in
            let firstPart = locationName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? locationName
            let firstPartProcessed = firstPart.replacingOccurrences(of: "County", with: "Co.")
            let iso3166 = address?["ISO3166-2-lvl4"] as? String ?? ""
            let processedLocation = iso3166.isEmpty ? firstPartProcessed : "\(iso3166), \(firstPartProcessed)"

            displayedLocation = processedLocation
            displayedAddress = address
            displayedElevation = address?["elevation"] as? String ?? ""
            editedInfo.location = processedLocation
            editedInfo.address = address
        }

        guard let creationDate = photoInfo.asset.creationDate else { return }

        WeatherFetcher.fetchHistoricTemp(at: coordinate, on: creationDate) { tempC in
            DispatchQueue.main.async {
                displayedTemperatureC = tempC != nil ? String(format: "%.0f°C", tempC!) : ""
                let f = tempC != nil ? tempC! * 9.0 / 5.0 + 32.0 : nil
                displayedTemperatureF = f != nil ? String(format: "%.0f°F", f!) : ""
                editedInfo.temperatureC = displayedTemperatureC
                editedInfo.temperatureF = displayedTemperatureF
            }
        }
    }
}