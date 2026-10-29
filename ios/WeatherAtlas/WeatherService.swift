import Foundation
import CoreLocation

struct Place: Identifiable, Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    var title: String { [name, admin1, country].compactMap { $0 }.joined(separator: ", ") }
    static let perth = Place(id: 0, name: "Perth", latitude: -31.95, longitude: 115.86, country: "Australia", admin1: nil)
}
struct Hourly: Decodable {
    let time: [Double]
    let temperature_2m: [Double?]
    let precipitation: [Double?]
    let wind_speed_10m: [Double?]
}
struct Forecast: Decodable { let hourly: Hourly }
struct RadarFrame: Decodable { let time: Double; let path: String }
struct RadarData: Decodable {
    struct Frames: Decodable { let past: [RadarFrame] }
    let host: String
    let radar: Frames
}
struct GridPoint {
    let latitude: Double
    let longitude: Double
    let latitudeStep: Double
    let longitudeStep: Double
}
enum WeatherError: LocalizedError {
    case response, incomplete
    var errorDescription: String? {
        switch self {
        case .response: return "Weather service unavailable. Please try again later."
        case .incomplete: return "Forecast does not cover the next six hours. Please refresh."
        }
    }
}
enum WeatherService {
    static func grid(_ place: Place) -> [GridPoint] {
        let lat = min(84, max(-84, place.latitude))
        let dy = 15.0 / 111.32
        let dx = dy / cos(lat * .pi / 180)
        return (0..<49).map { i in
            let lon = place.longitude + Double(i % 7 - 3) * dx
            return GridPoint(latitude: lat + Double(i / 7 - 3) * dy,
                             longitude: (lon + 540).truncatingRemainder(dividingBy: 360) - 180,
                             latitudeStep: dy, longitudeStep: dx)
        }
    }
    static func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .useProtocolCachePolicy
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw WeatherError.response }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func search(_ query: String) async throws -> [Place] {
        struct Results: Decodable { let results: [Place]? }
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: "en")]
        let response: Results = try await request(url.url!)
        return response.results ?? []
    }
    static func forecast(_ grid: [GridPoint]) async throws -> [Forecast] {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: grid.map { String(format: "%.4f", $0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: grid.map { String(format: "%.4f", $0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation,wind_speed_10m"),
            URLQueryItem(name: "forecast_hours", value: "10"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "cell_selection", value: "nearest")
        ]
        return try await request(url.url!)
    }
    static func radar() async throws -> RadarData {
        try await request(URL(string: "https://api.rainviewer.com/public/weather-maps.json")!)
    }
}
