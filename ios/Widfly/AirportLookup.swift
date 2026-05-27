import Foundation

struct Airport: Identifiable, Hashable {
    let code: String
    let name: String
    let city: String
    let country: String

    var id: String { code }
    var displayTitle: String { "\(city) (\(code))" }
    var displaySubtitle: String { "\(name), \(country)" }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard !normalized.isEmpty else { return false }
        return [code, name, city, country]
            .map { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased() }
            .contains { $0.contains(normalized) }
    }
}

enum AirportLookup {
    static let airports: [Airport] = [
        Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", country: "Turkey"),
        Airport(code: "SAW", name: "Sabiha Gokcen International Airport", city: "Istanbul", country: "Turkey"),
        Airport(code: "BJV", name: "Milas-Bodrum Airport", city: "Bodrum", country: "Turkey"),
        Airport(code: "DLM", name: "Dalaman Airport", city: "Dalaman", country: "Turkey"),
        Airport(code: "ADB", name: "Izmir Adnan Menderes Airport", city: "Izmir", country: "Turkey"),
        Airport(code: "AYT", name: "Antalya Airport", city: "Antalya", country: "Turkey"),
        Airport(code: "ESB", name: "Ankara Esenboga Airport", city: "Ankara", country: "Turkey"),
        Airport(code: "RTM", name: "Rotterdam The Hague Airport", city: "Rotterdam", country: "Netherlands"),
        Airport(code: "AMS", name: "Amsterdam Schiphol Airport", city: "Amsterdam", country: "Netherlands"),
        Airport(code: "EIN", name: "Eindhoven Airport", city: "Eindhoven", country: "Netherlands"),
        Airport(code: "DUS", name: "Dusseldorf Airport", city: "Dusseldorf", country: "Germany"),
        Airport(code: "CGN", name: "Cologne Bonn Airport", city: "Cologne", country: "Germany"),
        Airport(code: "FRA", name: "Frankfurt Airport", city: "Frankfurt", country: "Germany"),
        Airport(code: "BER", name: "Berlin Brandenburg Airport", city: "Berlin", country: "Germany"),
        Airport(code: "MUC", name: "Munich Airport", city: "Munich", country: "Germany"),
        Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", country: "France"),
        Airport(code: "ORY", name: "Paris Orly Airport", city: "Paris", country: "France"),
        Airport(code: "LHR", name: "Heathrow Airport", city: "London", country: "United Kingdom"),
        Airport(code: "LGW", name: "Gatwick Airport", city: "London", country: "United Kingdom"),
        Airport(code: "STN", name: "Stansted Airport", city: "London", country: "United Kingdom"),
        Airport(code: "BCN", name: "Barcelona-El Prat Airport", city: "Barcelona", country: "Spain"),
        Airport(code: "MAD", name: "Adolfo Suarez Madrid-Barajas Airport", city: "Madrid", country: "Spain"),
        Airport(code: "FCO", name: "Leonardo da Vinci-Fiumicino Airport", city: "Rome", country: "Italy"),
        Airport(code: "MXP", name: "Milan Malpensa Airport", city: "Milan", country: "Italy"),
        Airport(code: "JFK", name: "John F. Kennedy International Airport", city: "New York", country: "United States"),
        Airport(code: "EWR", name: "Newark Liberty International Airport", city: "New York", country: "United States"),
        Airport(code: "LAX", name: "Los Angeles International Airport", city: "Los Angeles", country: "United States"),
        Airport(code: "DXB", name: "Dubai International Airport", city: "Dubai", country: "United Arab Emirates"),
        Airport(code: "DOH", name: "Hamad International Airport", city: "Doha", country: "Qatar"),
        Airport(code: "BKK", name: "Suvarnabhumi Airport", city: "Bangkok", country: "Thailand"),
        Airport(code: "HND", name: "Haneda Airport", city: "Tokyo", country: "Japan"),
        Airport(code: "NRT", name: "Narita International Airport", city: "Tokyo", country: "Japan")
    ]

    static func suggestions(for query: String, limit: Int = 6) -> [Airport] {
        airports
            .filter { $0.matches(query) }
            .sorted { lhs, rhs in
                if lhs.code == query.uppercased() { return true }
                if rhs.code == query.uppercased() { return false }
                return lhs.displayTitle < rhs.displayTitle
            }
            .prefix(limit)
            .map { $0 }
    }

    static func resolve(_ input: String) -> Airport? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.uppercased()
        if let byCode = airports.first(where: { $0.code == uppercased }) {
            return byCode
        }
        return suggestions(for: trimmed, limit: 1).first
    }
}
