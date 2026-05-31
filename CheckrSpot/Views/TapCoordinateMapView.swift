#if os(iOS)
import SwiftUI
import MapKit
import CoreLocation

struct TapCoordinateMapView: UIViewRepresentable {
    let originalCoordinate: CLLocationCoordinate2D?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .excludingAll

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tap)

        if let initialCenter = selectedCoordinate ?? originalCoordinate {
            let region = MKCoordinateRegion(
                center: initialCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        mapView.removeAnnotations(mapView.annotations)

        if let originalCoordinate {
            mapView.addAnnotation(PinAnnotation(coordinate: originalCoordinate, kind: .original))
        }

        if let selectedCoordinate {
            mapView.addAnnotation(PinAnnotation(coordinate: selectedCoordinate, kind: .selected))
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TapCoordinateMapView

        init(parent: TapCoordinateMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.selectedCoordinate = coordinate
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? PinAnnotation else { return nil }
            let reuseIdentifier = "TapCoordinatePin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)

            view.annotation = annotation
            view.canShowCallout = false

            switch pin.kind {
            case .original:
                view.markerTintColor = .systemRed
                view.glyphText = "O"
            case .selected:
                view.markerTintColor = .systemBlue
                view.glyphText = "N"
            }

            return view
        }
    }
}

private final class PinAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case original
        case selected
    }

    dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
        super.init()
    }
}
#endif
