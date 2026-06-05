import Foundation
import Observation
import WidgetKit
import WidflyKit

@MainActor
@Observable
final class AppModel {
    var flights: [TrackedFlight] = []
    var activeSession: RefreshSession?
    var statusMessage: String?

    var isRefreshing: Bool { activeSession != nil }

    /// Most recent price fetch across all saved routes.
    var lastDataRefreshDate: Date? {
        flights.compactMap(\.lastUpdated).max()
    }

    var footerText: String {
        if let statusMessage,
           !statusMessage.isEmpty,
           statusMessage != "Updated." {
            return statusMessage
        }
        guard let date = lastDataRefreshDate else {
            return "Not refreshed yet"
        }
        return Self.formatLastUpdated(date)
    }

    init() {}

    func reload() {
        let loaded = FlightStore.load()
        var didSanitizeBookingURL = false
        flights = loaded.map { flight in
            var sanitized = flight
            if let raw = sanitized.bookingURL,
               !SkyscannerBookingURL.matches(flight: sanitized, urlString: raw) {
                sanitized.bookingURL = nil
                didSanitizeBookingURL = true
            }
            return sanitized
        }
        if didSanitizeBookingURL {
            persist()
        }
    }

    @discardableResult
    func addFlight(
        origin: String,
        destination: String,
        departureDate: Date,
        maxDurationMinutes: Int? = 8 * 60,
        departureTimeFilter: TimeFilter? = nil,
        arrivalTimeFilter: TimeFilter? = nil
    ) -> TrackedFlight {
        let flight = TrackedFlight(
            origin: origin.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            departureDate: departureDate,
            maxDurationMinutes: maxDurationMinutes,
            departureTimeFilter: departureTimeFilter,
            arrivalTimeFilter: arrivalTimeFilter
        )
        flights.append(flight)
        persist()
        return flight
    }

    func deleteFlights(at offsets: IndexSet) {
        flights.remove(atOffsets: offsets)
        persist()
    }

    func deleteFlight(_ flight: TrackedFlight) {
        flights.removeAll { $0.id == flight.id }
        persist()
    }

    func moveFlights(from source: IndexSet, to destination: Int) {
        flights.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func updateFlight(_ flight: TrackedFlight) {
        guard let i = flights.firstIndex(where: { $0.id == flight.id }) else { return }
        flights[i] = flight
        persist()
    }

    func refresh(flight: TrackedFlight) {
        startRefresh(flights: [flight])
    }

    func refresh(flights: [TrackedFlight]) {
        startRefresh(flights: flights)
    }

    func refreshAll() {
        startRefresh(flights: flights)
    }

    func updateBookingURL(for flight: TrackedFlight, url: URL) {
        guard let i = flights.firstIndex(where: { $0.id == flight.id }) else { return }
        flights[i].bookingURL = url.absoluteString
        persist()
    }

    func sessionDidDismiss() {
        activeSession = nil
    }

    private func startRefresh(flights: [TrackedFlight]) {
        guard activeSession == nil else { return }
        guard !flights.isEmpty else { return }

        let session = RefreshSession(flights: flights)
        session.onFlightUpdated = { [weak self] updated in
            guard let self else { return }
            if let i = self.flights.firstIndex(where: { $0.id == updated.id }) {
                self.flights[i] = updated
                self.persist()
            }
        }
        session.onCompleted = { [weak self] in
            guard let self else { return }
            if session.hasError {
                self.statusMessage = "Some routes could not be updated."
            } else {
                self.statusMessage = nil
            }
            WidgetCenter.shared.reloadAllTimelines()
        }

        activeSession = session
    }

    private func persist() {
        do {
            _ = try FlightStore.save(flights)
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private static func formatLastUpdated(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return "Last updated at \(time)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Last updated yesterday at \(time)"
        }
        let day = date.formatted(date: .abbreviated, time: .omitted)
        return "Last updated \(day) at \(time)"
    }
}
