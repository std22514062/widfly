import Foundation
import Observation
import WebKit
import WidflyKit

@MainActor
@Observable
final class RefreshSession: Identifiable {
    let id = UUID()
    let flights: [TrackedFlight]

    var currentIndex: Int = 0
    var statusMessage: String = "Preparing…"
    var isCompleted: Bool = false
    var hasError: Bool = false

    private let scraper = SkyscannerWebScraper()
    private var isCancelled = false
    private var didStart = false
    private var preparedWebView: WKWebView?

    var onFlightUpdated: (TrackedFlight) -> Void = { _ in }
    var onCompleted: () -> Void = {}

    /// Lazily created once the refresh sheet is on screen.
    var webView: WKWebView {
        if let preparedWebView { return preparedWebView }
        let view = scraper.attachableWebView()
        preparedWebView = view
        return view
    }

    init(flights: [TrackedFlight]) {
        self.flights = flights
    }

    func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        _ = webView
        await start()
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
            options.departureTimeFilter = flight.departureTimeFilter
            options.arrivalTimeFilter = flight.arrivalTimeFilter

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
                    stopsSummary: result.stopsSummary,
                    airlineName: result.airlineName
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
