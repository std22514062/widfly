import Foundation
import WidflyKit

enum FlightListSort: String, CaseIterable, Identifiable {
    case dateAscending
    case dateDescending
    case priceAscending
    case priceDescending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAscending: return "Date · Soonest first"
        case .dateDescending: return "Date · Latest first"
        case .priceAscending: return "Price · Lowest first"
        case .priceDescending: return "Price · Highest first"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAscending: return "calendar"
        case .dateDescending: return "calendar.badge.clock"
        case .priceAscending: return "arrow.down.circle"
        case .priceDescending: return "arrow.up.circle"
        }
    }

    func sorted(_ flights: [TrackedFlight]) -> [TrackedFlight] {
        switch self {
        case .dateAscending:
            return flights.sorted { $0.departureDate < $1.departureDate }
        case .dateDescending:
            return flights.sorted { $0.departureDate > $1.departureDate }
        case .priceAscending:
            return flights.sorted { lhs, rhs in
                compareOptionalPrice(lhs.lastPrice, rhs.lastPrice, ascending: true)
            }
        case .priceDescending:
            return flights.sorted { lhs, rhs in
                compareOptionalPrice(lhs.lastPrice, rhs.lastPrice, ascending: false)
            }
        }
    }

    private func compareOptionalPrice(_ lhs: Decimal?, _ rhs: Decimal?, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case (nil, _):
            return false
        case (_, nil):
            return true
        case (let left?, let right?):
            return ascending ? left < right : left > right
        }
    }

    static func loadSaved() -> FlightListSort {
        guard let raw = UserDefaults.standard.string(forKey: "widfly.flightListSort"),
              let order = FlightListSort(rawValue: raw) else {
            return .dateAscending
        }
        return order
    }
}
