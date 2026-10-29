import SwiftUI
import MapKit
import CoreLocation

enum WeatherLayer: String, CaseIterable { case rain = "Rain", temperature = "Temperature", radar = "Radar" }

@MainActor final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var place = Place.perth
    @Published var query = ""
    @Published var results: [Place] = []
    @Published var layer = WeatherLayer.rain
    @Published var range = ForecastRange.six
    @Published var source = ForecastSource.automatic
    @Published var step = 0.0
    @Published var grid: [GridPoint] = []
    @Published var forecasts: [Forecast] = []
    @Published var indices: [Int] = []
    @Published var radar: RadarData?
    @Published var loading = false
    @Published var message = ""
    @Published var radarMessage = ""
    @Published var loadedAt: Date?
    private let locationManager = CLLocationManager()
    private var generation = UUID()
    private var searchGeneration = UUID()
    // Repeated visits within ten minutes reuse the same 49 samples.
    private var cache: [String: (Date, [Forecast])] = [:]

    override init() { super.init(); locationManager.delegate = self }
    var center: Hourly? { forecasts.count == 49 ? forecasts[24].hourly : nil }
    var maxStep: Double { layer == .radar ? Double(max(0, (radar?.radar.past.count ?? 1) - 1)) : Double(range.rawValue) }
    var hourlyIndex: Int? { indices.indices.contains(Int(step)) ? indices[Int(step)] : nil }
    var radarFrame: RadarFrame? {
        guard let frames = radar?.radar.past, frames.indices.contains(Int(step)) else { return nil }
        return frames[Int(step)]
    }
    var validDate: Date? {
        if layer == .radar { return radarFrame.map { Date(timeIntervalSince1970: $0.time) } }
        guard let h = center, let i = hourlyIndex else { return nil }
        return Date(timeIntervalSince1970: h.time[i])
    }
    func formatted(_ value: Double?, digits: Int = 0) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.*f", digits, value)
    }
    func value(_ index: Int) -> Double? {
        guard forecasts.indices.contains(index), let i = hourlyIndex else { return nil }
        let h = forecasts[index].hourly
        return layer == .temperature ? h.temperature_2m[i] : h.precipitation[i]
    }
    func load(_ newPlace: Place? = nil) async {
        let token = UUID(); generation = token
        if let newPlace { place = newPlace }
        loading = true; forecasts = []; indices = []; message = ""; loadedAt = nil; step = 0
        let points = WeatherService.grid(place)
        let selectedSource = source
        let key = selectedSource.rawValue + String(format: "%.3f,%.3f", place.latitude, place.longitude)
        do {
            let data: [Forecast]
            let timestamp: Date
            if let cached = cache[key], Date().timeIntervalSince(cached.0) < 600 {
                data = cached.1; timestamp = cached.0
            } else {
                data = try await WeatherService.forecast(points, source: selectedSource); timestamp = Date()
                if cache.count > 15 { cache.removeAll() }
                cache[key] = (timestamp, data)
            }
            guard generation == token else { return }
            guard data.count == 49, let first = data[24].hourly.time.firstIndex(where: { $0 >= Date().timeIntervalSince1970 }), data[24].hourly.time.count > first + range.rawValue,
                  data.allSatisfy({ $0.hourly.time == data[24].hourly.time && $0.hourly.temperature_2m.count > first + range.rawValue && $0.hourly.precipitation.count > first + range.rawValue && $0.hourly.wind_speed_10m.count > first + range.rawValue }) else { throw WeatherError.incomplete }
            grid = points; forecasts = data; indices = Array(first...first+range.rawValue); loadedAt = timestamp
        } catch { if generation == token { message = error.localizedDescription } }
        if generation == token { loading = false }
    }
    func changeRange() {
        step = 0
        guard let h = center, let first = h.time.firstIndex(where: { $0 >= Date().timeIntervalSince1970 }), h.time.count > first + range.rawValue else {
            if !loading { Task { await load() } }
            return
        }
        indices = Array(first...first+range.rawValue)
    }
    var dailySummaries: [DailySummary] {
        guard range.rawValue > 24, let h = center, let first = indices.first else { return [] }
        return (0..<(range.rawValue/24)).map { day in
            let start = first + day * 24 + 1, end = start + 24
            let temps = h.temperature_2m[start..<end].compactMap { $0 }
            let rain = h.precipitation[start..<end].compactMap { $0 }
            return DailySummary(id: day, start: Date(timeIntervalSince1970: h.time[start-1]), end: Date(timeIntervalSince1970: h.time[end-1]), minimum: temps.count == 24 ? temps.min() : nil, maximum: temps.count == 24 ? temps.max() : nil, rain: rain.count == 24 ? rain.reduce(0,+) : nil)
        }
    }
    func loadRadar() async {
        do { radar = try await WeatherService.radar(); radarMessage = ""; if layer == .radar { step = maxStep } }
        catch { radarMessage = "Radar unavailable: \(error.localizedDescription)" }
    }
    func search() async {
        let token = UUID(); searchGeneration = token
        guard query.trimmingCharacters(in: .whitespaces).count > 1 else { return }
        do { let found = try await WeatherService.search(query); if searchGeneration == token { results = found; message = found.isEmpty ? "No cities found." : "" } }
        catch { if searchGeneration == token { message = error.localizedDescription } }
    }
    func locate() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: locationManager.requestLocation()
        default: message = "Location is unavailable. Search for a city, or allow location in Settings."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let p = locations.last else { return }
        Task { await load(Place(id: -1, name: "My location", latitude: p.coordinate.latitude, longitude: p.coordinate.longitude, country: nil, admin1: nil)) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = "Could not locate you. Search for a city instead." }
}
