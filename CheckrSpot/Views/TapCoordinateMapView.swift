#if os(iOS)
import SwiftUI
import MapKit
import CoreLocation

struct TapCoordinateMapView: UIViewRepresentable {
    let originalCoordinate: CLLocationCoordinate2D?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let specimenPins: [SpecimenMapPin]

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
        context.coordinator.updateAnnotationsIfNeeded(on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TapCoordinateMapView
        private var lastAnnotationSignature: String?
        private var hasPerformedInitialFit = false

        init(parent: TapCoordinateMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.selectedCoordinate = coordinate
        }

        func updateAnnotationsIfNeeded(on mapView: MKMapView) {
            let signature = annotationSignature()
            guard signature != lastAnnotationSignature else { return }
            lastAnnotationSignature = signature

            mapView.removeAnnotations(mapView.annotations)

            if let originalCoordinate = parent.originalCoordinate {
                mapView.addAnnotation(PinAnnotation(coordinate: originalCoordinate, kind: .original))
            }

            if let selectedCoordinate = parent.selectedCoordinate {
                mapView.addAnnotation(PinAnnotation(coordinate: selectedCoordinate, kind: .selected))
            }

            for specimen in parent.specimenPins {
                mapView.addAnnotation(
                    PinAnnotation(
                        coordinate: specimen.coordinate,
                        kind: .specimen,
                        title: specimen.qrCode,
                        subtitle: specimen.time
                    )
                )
            }

            fitMapToAllPinsIfNeeded(on: mapView)
        }

        private func annotationSignature() -> String {
            var chunks: [String] = []

            if let original = parent.originalCoordinate {
                chunks.append(String(format: "O:%.6f,%.6f", original.latitude, original.longitude))
            }

            if let selected = parent.selectedCoordinate {
                chunks.append(String(format: "S:%.6f,%.6f", selected.latitude, selected.longitude))
            }

            for specimen in parent.specimenPins {
                let coord = specimen.coordinate
                chunks.append(String(format: "P:%.6f,%.6f:%@:%@", coord.latitude, coord.longitude, specimen.qrCode, specimen.time))
            }

            return chunks.sorted().joined(separator: "|")
        }

        /// Frames all pins once, when the map first shows them. Afterwards the
        /// region belongs to the user: adding or moving a pin must never move
        /// the camera out from under them.
        func fitMapToAllPinsIfNeeded(on mapView: MKMapView) {
            let coordinates: [CLLocationCoordinate2D] = mapView.annotations.map(\.coordinate)
            guard !coordinates.isEmpty else { return }

            guard !hasPerformedInitialFit else { return }
            hasPerformedInitialFit = true

            if coordinates.count == 1, let coordinate = coordinates.first {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapView.setRegion(region, animated: true)
                return
            }

            var mapRect = MKMapRect.null
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                let rect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                mapRect = mapRect.union(rect)
            }

            mapView.setVisibleMapRect(
                mapRect,
                edgePadding: UIEdgeInsets(top: 45, left: 30, bottom: 45, right: 30),
                animated: true
            )
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let reuseIdentifier = "SpecimenClusterPin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.annotation = annotation
                view.markerTintColor = .systemOrange
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.canShowCallout = false
                view.displayPriority = .required
                return view
            }

            guard let pin = annotation as? PinAnnotation else { return nil }
            switch pin.kind {
            case .original, .selected:
                let reuseIdentifier = "TapCoordinatePin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)

                view.annotation = annotation
                view.canShowCallout = false

                // O and N usually sit on the exact same coordinate until the
                // user moves N. Rank them explicitly so N always wins the
                // collision and draws on top, rather than the winner being
                // whichever MapKit happened to lay out last.
                switch pin.kind {
                case .original:
                    view.markerTintColor = .systemRed
                    view.glyphText = "O"
                    view.displayPriority = .defaultHigh
                    view.zPriority = .defaultUnselected
                case .selected:
                    view.markerTintColor = .systemBlue
                    view.glyphText = "N"
                    view.displayPriority = .required
                    view.zPriority = .max
                case .specimen:
                    break
                }

                return view
            case .specimen:
                let reuseIdentifier = "SpecimenNativePin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.annotation = annotation
                view.markerTintColor = .systemOrange
                view.glyphText = ""
                view.clusteringIdentifier = "specimen"
                view.canShowCallout = true
                view.titleVisibility = .visible
                view.subtitleVisibility = .visible
                return view
            }
        }
    }
}

private final class PinAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case original
        case selected
        case specimen
    }

    @objc dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind
    @objc dynamic var title: String?
    @objc dynamic var subtitle: String?

    init(coordinate: CLLocationCoordinate2D, kind: Kind, title: String? = nil, subtitle: String? = nil) {
        self.coordinate = coordinate
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}

struct SpecimenMapPin {
    let coordinate: CLLocationCoordinate2D
    let qrCode: String
    let time: String
}
#endif
