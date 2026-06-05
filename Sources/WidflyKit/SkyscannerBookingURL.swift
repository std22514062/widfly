import Foundation

public enum SkyscannerBookingURL {
    /// Returns a stored config URL only when it matches this flight's route and departure date.
    public static func validated(for flight: TrackedFlight) -> URL? {
        guard let raw = flight.bookingURL,
              raw.contains("/config/"),
              let url = URL(string: raw),
              matches(flight: flight, urlString: raw) else {
            return nil
        }
        return url
    }

    public static func searchURL(for flight: TrackedFlight) -> URL {
        SkyscannerURLBuilder.flightSearchURL(
            origin: flight.origin,
            destination: flight.destination,
            departureDate: flight.departureDate,
            options: .turkeyInteractive
        )
    }

    public static func matches(flight: TrackedFlight, urlString: String) -> Bool {
        let lower = urlString.lowercased()
        guard lower.contains(flight.origin.lowercased()),
              lower.contains(flight.destination.lowercased()) else {
            return false
        }
        return lower.contains(datePathComponent(flight.departureDate))
    }

    private static func datePathComponent(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let y = calendar.component(.year, from: date) % 100
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%02d%02d%02d", y, m, d)
    }
}
