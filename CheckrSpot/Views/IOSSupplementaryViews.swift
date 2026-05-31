#if os(iOS)
import SwiftUI
import CoreLocation
import WebKit

final class IOSLocationStatusMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var hasPreciseFix: Bool = false
    @Published var latestLocation: CLLocation?
    @Published var canAttachGPS: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = true
    }

    func startUpdating() {
        let status = manager.authorizationStatus
        updateAuthorizationState(status)
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.requestLocation()
            updatePreciseState(using: manager.location)
        default:
            manager.stopUpdatingLocation()
            latestLocation = nil
            hasPreciseFix = false
        }
    }

    func requestLocationUpdate() {
        let status = manager.authorizationStatus
        updateAuthorizationState(status)
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
            updatePreciseState(using: manager.location)
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            manager.stopUpdatingLocation()
            latestLocation = nil
            hasPreciseFix = false
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startUpdating()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        updatePreciseState(using: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        updatePreciseState(using: manager.location)
    }

    private func updatePreciseState(using location: CLLocation?) {
        latestLocation = location ?? manager.location
        let hasFullAccuracy = manager.accuracyAuthorization == .fullAccuracy
        let horizontalAccuracy = latestLocation?.horizontalAccuracy ?? CLLocationAccuracy.greatestFiniteMagnitude
        let hasAccurateFix = horizontalAccuracy > 0 && horizontalAccuracy <= 50
        hasPreciseFix = hasFullAccuracy && hasAccurateFix
    }

    private func updateAuthorizationState(_ status: CLAuthorizationStatus) {
        canAttachGPS = (status == .authorizedAlways || status == .authorizedWhenInUse)
        if !canAttachGPS {
            latestLocation = nil
            hasPreciseFix = false
        }
    }
}

struct CameraPickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage, [String: Any]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage, [String: Any]) -> Void

        init(onImagePicked: @escaping (UIImage, [String: Any]) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let metadata = info[.mediaMetadata] as? [String: Any] ?? [:]
                onImagePicked(image, metadata)
            }
            picker.dismiss(animated: true)
        }
    }
}

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

        if let cssURL = Bundle.main.url(forResource: "styles", withExtension: "css"),
           let css = try? String(contentsOf: cssURL, encoding: .utf8) {
            htmlString = htmlString.replacingOccurrences(
                of: "<link rel=\"stylesheet\" href=\"/styles.css\">",
                with: "<style>\(css)</style>"
            )
        }

        if let jsURL = Bundle.main.url(forResource: "script", withExtension: "js"),
           var js = try? String(contentsOf: jsURL, encoding: .utf8) {
            let jsonData = jsonDataProvider()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

            let inlineDataScript = "window.__specimensData = \(jsonString);\n"
            js = js.replacingOccurrences(
                of: "fetch('/specimens.json')",
                with: "Promise.resolve({ ok: true, json: () => Promise.resolve(window.__specimensData) })"
            )

            htmlString = htmlString.replacingOccurrences(
                of: "<script type=\"module\" src=\"/script.js\"></script>",
                with: "<script type=\"module\">\(inlineDataScript)\(js)</script>"
            )
        }

        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}
#endif
