import Foundation

public struct TrackedFlight: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var origin: String
    public var destination: String
    public var departureDate: Date
    public var lastPrice: Decimal?
    public var previousPrice: Decimal?
    public var currencyCode: String
    public var lastUpdated: Date?
    public var lastError: String?
    /// Maximum total flight time the user is willing to accept, in minutes.
    /// `nil` means no filter.
    public var maxDurationMinutes: Int?
    /// Skyscanner selected-itinerary URL (`/config/...`) for the fetched result.
    public var bookingURL: String?
    /// Departure time text as shown by Skyscanner (for example `04:55`).
    public var departureTime: String?
    /// Arrival time text as shown by Skyscanner (for example `11:10`).
    public var arrivalTime: String?
    /// Total duration of the fetched itinerary, in minutes.
    public var durationMinutes: Int?
    /// Transfer/stopover summary extracted from the selected result card.
    public var stopsSummary: String?

    public init(
        id: UUID = UUID(),
        origin: String,
        destination: String,
        departureDate: Date,
        lastPrice: Decimal? = nil,
        previousPrice: Decimal? = nil,
        currencyCode: String = "TRY",
        lastUpdated: Date? = nil,
        lastError: String? = nil,
        maxDurationMinutes: Int? = 8 * 60,
        bookingURL: String? = nil,
        departureTime: String? = nil,
        arrivalTime: String? = nil,
        durationMinutes: Int? = nil,
        stopsSummary: String? = nil
    ) {
        self.id = id
        self.origin = origin.uppercased()
        self.destination = destination.uppercased()
        self.departureDate = departureDate
        self.lastPrice = lastPrice
        self.previousPrice = previousPrice
        self.currencyCode = currencyCode
        self.lastUpdated = lastUpdated
        self.lastError = lastError
        self.maxDurationMinutes = maxDurationMinutes
        self.bookingURL = bookingURL
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.stopsSummary = stopsSummary
    }

    public var routeLabel: String {
        "\(origin) → \(destination)"
    }

    public var maxDurationLabel: String? {
        guard let maxDurationMinutes else { return nil }
        let h = maxDurationMinutes / 60
        let m = maxDurationMinutes % 60
        if m == 0 { return "≤ \(h)h" }
        return "≤ \(h)h \(m)m"
    }

    public var fetchedDurationLabel: String? {
        guard let durationMinutes else { return nil }
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    public var priceDelta: Decimal? {
        guard let lastPrice, let previousPrice else { return nil }
        return lastPrice - previousPrice
    }

    public mutating func applyFetchedPrice(
        _ price: Decimal,
        currency: String,
        at date: Date = .now,
        bookingURL: String? = nil,
        departureTime: String? = nil,
        arrivalTime: String? = nil,
        durationMinutes: Int? = nil,
        stopsSummary: String? = nil
    ) {
        if let lastPrice, lastPrice != price {
            previousPrice = lastPrice
        }
        lastPrice = price
        currencyCode = currency
        lastUpdated = date
        self.bookingURL = bookingURL
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.stopsSummary = stopsSummary
        lastError = nil
    }

    public mutating func applyError(_ message: String) {
        lastError = message
    }
}
