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

    init() {
        reload()
    }

    func reload() {
        flights = FlightStore.load()
    }

    func addFlight(
        origin: String,
        destination: String,
        departureDate: Date,
        maxDurationMinutes: Int? = 8 * 60
    ) {
        let flight = TrackedFlight(
            origin: origin.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            departureDate: departureDate,
            maxDurationMinutes: maxDurationMinutes
        )
        flights.append(flight)
        persist()
    }

    func deleteFlights(at offsets: IndexSet) {
        flights.remove(atOffsets: offsets)
        persist()
    }

    func deleteFlight(_ flight: TrackedFlight) {
        flights.removeAll { $0.id == flight.id }
        persist()
    }

    func refresh(flight: TrackedFlight) {
        startRefresh(flights: [flight])
    }

    func refreshAll() {
        startRefresh(flights: flights)
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
            self.statusMessage = session.hasError
                ? "Some routes could not be updated."
                : "Updated."
            WidgetCenter.shared.reloadAllTimelines()
        }

        activeSession = session
        Task { await session.start() }
    }

    private func persist() {
        do {
            _ = try FlightStore.save(flights)
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
