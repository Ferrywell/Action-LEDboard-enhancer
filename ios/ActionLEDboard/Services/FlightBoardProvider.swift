import Foundation

/// OpenSky Network (no API key). For production, replace with your aviation API + URLSession config.
enum FlightBoardProvider {
    struct Config: Sendable {
        /// Bounding box in degrees (default: rough NL / BE area — adjust in UI later).
        var lamin: Double = 50.5
        var lomin: Double = 3.0
        var lamax: Double = 53.5
        var lomax: Double = 7.5
    }

    enum FlightError: LocalizedError {
        case invalidURL
        case http(Int)
        case decode

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Ongeldige URL."
            case .http(let c): return "HTTP \(c)"
            case .decode: return "Kon vluchtdata niet lezen."
            }
        }
    }

    static func fetchAircraftCount(config: Config = Config()) async throws -> Int {
        var c = URLComponents(string: "https://opensky-network.org/api/states/all")!
        c.queryItems = [
            URLQueryItem(name: "lamin", value: String(config.lamin)),
            URLQueryItem(name: "lomin", value: String(config.lomin)),
            URLQueryItem(name: "lamax", value: String(config.lamax)),
            URLQueryItem(name: "lomax", value: String(config.lomax)),
        ]
        guard let url = c.url else { throw FlightError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw FlightError.decode }
        guard (200...299).contains(http.statusCode) else { throw FlightError.http(http.statusCode) }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let states = obj?["states"] as? [[Any]]
        return states?.count ?? 0
    }

    static func summaryLines(config: Config = Config()) async throws -> [String] {
        let n = try await fetchAircraftCount(config: config)
        return ["OpenSky", "regio", "\(n)", "vliegtuig"]
    }
}
