import Foundation
import Observation
import WebKit
import WidflyKit

@MainActor
@Observable
final class RefreshSession: Identifiable {
    let id = UUID()
    let webView: WKWebView
    let flights: [TrackedFlight]

    var currentIndex: Int = 0
    var statusMessage: String = "Preparing…"
    var isCompleted: Bool = false
    var hasError: Bool = false

    private let scraper: SkyscannerWebScraper
    private var isCancelled = false

    var onFlightUpdated: (TrackedFlight) -> Void = { _ in }
    var onCompleted: () -> Void = {}

    init(flights: [TrackedFlight]) {
        self.scraper = SkyscannerWebScraper()
        self.webView = scraper.attachableWebView()
        self.flights = flights
    }

    func start() async {
        guard !flights.isEmpty else {
            isCompleted = true
            onCompleted()
            return
        }

        for (index, flight) in flights.enumerated() {
            if isCancelled { break }
            currentIndex = index
            statusMessage = progressPrefix + "Loading \(flight.routeLabel)…"

            var options = SkyscannerSearchOptions.turkeyInteractive
            options.currency = flight.currencyCode
            options.maxDurationMinutes = flight.maxDurationMinutes

            var updated = flight
            do {
                let result = try await scraper.fetchLowestPrice(
                    origin: flight.origin,
                    destination: flight.destination,
                    departureDate: flight.departureDate,
                    options: options
                )
                if isCancelled { break }
                updated.applyFetchedPrice(
                    result.amount,
                    currency: result.currency,
                    bookingURL: result.bookingURL,
                    departureTime: result.departureTime,
                    arrivalTime: result.arrivalTime,
                    durationMinutes: result.durationMinutes,
                    stopsSummary: result.stopsSummary
                )
                let priceText = PriceFormatting.string(amount: result.amount, currency: result.currency)
                statusMessage = progressPrefix + "✓ \(flight.routeLabel) — \(priceText)"
            } catch {
                if isCancelled { break }
                updated.applyError(error.localizedDescription)
                statusMessage = progressPrefix + "✗ \(flight.routeLabel): \(error.localizedDescription)"
                hasError = true
            }
            onFlightUpdated(updated)
        }

        isCompleted = true
        onCompleted()
    }

    func cancel() {
        isCancelled = true
        scraper.cancel()
    }

    private var progressPrefix: String {
        flights.count > 1 ? "(\(currentIndex + 1)/\(flights.count)) " : ""
    }
}
