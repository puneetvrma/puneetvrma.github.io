import SwiftUI
import MapKit

struct WeatherMap: UIViewRepresentable {
    @ObservedObject var model: WeatherModel
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let identity = "\(model.place.latitude),\(model.place.longitude)"
        if context.coordinator.location != identity {
            context.coordinator.location = identity
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: model.place.latitude, longitude: model.place.longitude), latitudinalMeters: 125000, longitudinalMeters: 125000), animated: true)
            map.removeAnnotations(map.annotations)
            let pin = MKPointAnnotation()
            pin.coordinate = CLLocationCoordinate2D(latitude: model.place.latitude, longitude: model.place.longitude)
            pin.title = model.place.name
            map.addAnnotation(pin)
        }
        let version = "\(identity)-\(model.layer.rawValue)-\(model.step)-\(model.loadedAt?.timeIntervalSince1970 ?? 0)-\(model.radarFrame?.path ?? "")"
        guard context.coordinator.version != version else { return }
        context.coordinator.version = version
        map.removeOverlays(map.overlays)
        if model.layer == .radar {
            if let data = model.radar, let f = model.radarFrame {
                let overlay = RadarOverlay(urlTemplate: "\(data.host)\(f.path)/256/{z}/{x}/{y}/2/1_1.png")
                overlay.maximumZ = 18
                map.addOverlay(overlay, level: .aboveRoads)
            }
        } else if model.forecasts.count == 49 {
            for (i, point) in model.grid.enumerated() {
                let dy = point.latitudeStep / 2, dx = point.longitudeStep / 2
                let coordinates = [CLLocationCoordinate2D(latitude: point.latitude-dy, longitude: point.longitude-dx), CLLocationCoordinate2D(latitude: point.latitude+dy, longitude: point.longitude-dx), CLLocationCoordinate2D(latitude: point.latitude+dy, longitude: point.longitude+dx), CLLocationCoordinate2D(latitude: point.latitude-dy, longitude: point.longitude+dx)]
                let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
                let v = model.value(i)
                polygon.title = Self.color(v, layer: model.layer)
                map.addOverlay(polygon, level: .aboveRoads)
            }
        }
    }
    static func color(_ value: Double?, layer: WeatherLayer) -> String {
        guard let value else { return "missing" }
        if layer == .temperature { return "temp:\(value)" }
        return value < 0.1 ? "dry" : value < 0.5 ? "light" : value < 2 ? "rain" : value < 5 ? "heavy" : "intense"
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var location = ""
        var version = ""
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay { let r = MKTileOverlayRenderer(tileOverlay: tile); r.alpha = 0.65; return r }
            guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: polygon)
            let key = polygon.title ?? "missing"
            let color: UIColor
            if key.hasPrefix("temp:"), let v = Double(key.dropFirst(5)) {
                color = UIColor(hue: CGFloat(max(0,min(260,240-(v+10)*5))/360), saturation: 0.75, brightness: 0.85, alpha: 0.5)
            } else {
                switch key {
                case "dry": color = UIColor.systemMint.withAlphaComponent(0.08)
                case "light": color = UIColor.systemMint.withAlphaComponent(0.45)
                case "rain": color = UIColor.systemTeal.withAlphaComponent(0.55)
                case "heavy": color = UIColor.systemBlue.withAlphaComponent(0.6)
                case "intense": color = UIColor.systemPurple.withAlphaComponent(0.65)
                default: color = UIColor.systemGray.withAlphaComponent(0.4)
                }
            }
            renderer.fillColor = color; renderer.lineWidth = 0
            return renderer
        }
    }
}

// RainViewer publishes only through zoom 7. Crop and upscale its native tiles at
// higher MapKit zoom levels; never request nonexistent high-resolution radar.
final class RadarOverlay: MKTileOverlay {
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let z = min(path.z, 7)
        let factor = pow(2.0, Double(path.z - z))
        let x = Int(Double(path.x) / factor), y = Int(Double(path.y) / factor)
        guard let template = urlTemplate,
              let url = URL(string: template.replacingOccurrences(of: "{z}", with: "\(z)").replacingOccurrences(of: "{x}", with: "\(x)").replacingOccurrences(of: "{y}", with: "\(y)")) else { result(nil, WeatherError.response); return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let response = response as? HTTPURLResponse, response.statusCode == 200, let data else { result(nil, error ?? WeatherError.response); return }
            if path.z <= 7 { result(data, nil); return }
            guard let image = UIImage(data: data)?.cgImage else { result(nil, WeatherError.response); return }
            let size = Double(image.width) / factor
            let crop = CGRect(x: Double(path.x - x * Int(factor)) * size, y: Double(path.y - y * Int(factor)) * size, width: size, height: size)
            guard let cropped = image.cropping(to: crop) else { result(nil, WeatherError.response); return }
            result(UIImage(cgImage: cropped).pngData(), nil)
        }.resume()
    }
}
