import SwiftUI
import WidflyKit
import WidgetKit

struct WidflyEntry: TimelineEntry {
    let date: Date
    let flights: [TrackedFlight]
}

struct WidflyProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidflyEntry {
        WidflyEntry(date: .now, flights: sampleFlights)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidflyEntry) -> Void) {
        let flights = context.isPreview ? sampleFlights : FlightStore.load()
        completion(WidflyEntry(date: .now, flights: flights))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidflyEntry>) -> Void) {
        let entry = WidflyEntry(date: .now, flights: FlightStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: .now)
            ?? .now.addingTimeInterval(7200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleFlights: [TrackedFlight] {
        let now = Date()
        return [
            TrackedFlight(origin: "BJV", destination: "AMS",
                          departureDate: now.addingTimeInterval(86_400 * 20),
                          lastPrice: 5092, previousPrice: 5292, currencyCode: "TRY",
                          lastUpdated: now),
            TrackedFlight(origin: "IST", destination: "JFK",
                          departureDate: now.addingTimeInterval(86_400 * 50),
                          lastPrice: 18_420, previousPrice: 18_070, currencyCode: "TRY",
                          lastUpdated: now),
            TrackedFlight(origin: "BJV", destination: "RTM",
                          departureDate: now.addingTimeInterval(86_400 * 25),
                          lastPrice: 5126, previousPrice: 5201, currencyCode: "TRY",
                          lastUpdated: now),
        ]
    }
}

// MARK: - Shared helpers

private enum WidgetPalette {
    static let navy = Color(red: 0.043, green: 0.145, blue: 0.271)
    static let amber = Color(red: 0.961, green: 0.773, blue: 0.094)
    static let dropGreen = Color(red: 0.40, green: 0.85, blue: 0.55)
    static let muted = Color.white.opacity(0.55)
    static let divider = Color.white.opacity(0.14)
}

private enum WidgetFlightList {
    static func upcoming(from flights: [TrackedFlight]) -> [TrackedFlight] {
        let cutoff = Calendar.current.startOfDay(for: .now)
        return flights
            .filter { $0.departureDate >= cutoff }
            .sorted { $0.departureDate < $1.departureDate }
    }

    static func cheapestPriced(from flights: [TrackedFlight]) -> TrackedFlight? {
        let upcoming = upcoming(from: flights)
        let priced = upcoming.filter { $0.lastPrice != nil }
        if let cheapest = priced.min(by: {
            ($0.lastPrice ?? .greatestFiniteMagnitude) < ($1.lastPrice ?? .greatestFiniteMagnitude)
        }) {
            return cheapest
        }
        return upcoming.first
    }

    static func lastRefreshDate(from flights: [TrackedFlight]) -> Date? {
        flights.compactMap(\.lastUpdated).max()
    }

    static func footerText(for date: Date?) -> String? {
        guard let date else { return nil }
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return "Updated \(time)"
        }
        return "Updated \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

// MARK: - Root view

struct WidflyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidflyEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(flights: entry.flights)
        default:
            MediumWidgetView(flights: entry.flights)
        }
    }
}

// MARK: - Small (cheapest fare)

private struct SmallWidgetView: View {
    let flights: [TrackedFlight]

    private var flight: TrackedFlight? {
        WidgetFlightList.cheapestPriced(from: flights)
    }

    var body: some View {
        if let flight {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                routeRow(flight)
                    .padding(.bottom, 6)

                Text(dateText(for: flight))
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(WidgetPalette.muted)
                    .padding(.bottom, 8)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    priceText(for: flight)
                    Spacer(minLength: 0)
                    DeltaBadge(flight: flight, compact: true)
                }

                Spacer(minLength: 0)

                if let footer = WidgetFlightList.footerText(for: WidgetFlightList.lastRefreshDate(from: flights)) {
                    Text(footer)
                        .font(.system(size: 9, weight: .semibold, design: .default))
                        .foregroundStyle(WidgetPalette.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            EmptyWidgetState(compact: true)
        }
    }

    private func routeRow(_ flight: TrackedFlight) -> some View {
        HStack(spacing: 8) {
            Text(flight.origin)
            Image(systemName: "airplane")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(flight.destination)
            Spacer(minLength: 0)
        }
        .font(.system(size: 22, weight: .black, design: .default))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.8)
        .lineLimit(1)
    }

    @ViewBuilder
    private func priceText(for flight: TrackedFlight) -> some View {
        if let price = flight.lastPrice {
            Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                .font(.system(size: 26, weight: .heavy, design: .default).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("—")
                .font(.system(size: 26, weight: .heavy, design: .default))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func dateText(for flight: TrackedFlight) -> String {
        flight.departureDate
            .formatted(.dateTime.day().month(.abbreviated))
            .uppercased()
    }
}

// MARK: - Medium (upcoming list)

private struct MediumWidgetView: View {
    let flights: [TrackedFlight]

    private var upcoming: [TrackedFlight] {
        Array(WidgetFlightList.upcoming(from: flights).prefix(3))
    }

    var body: some View {
        if upcoming.isEmpty {
            EmptyWidgetState(compact: false)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, flight in
                    MediumFlightRow(flight: flight)
                    if index < upcoming.count - 1 {
                        Rectangle()
                            .fill(WidgetPalette.divider)
                            .frame(height: 1)
                            .padding(.vertical, 5)
                    }
                }

                Spacer(minLength: 0)

                if let footer = WidgetFlightList.footerText(for: WidgetFlightList.lastRefreshDate(from: flights)) {
                    Text(footer)
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(WidgetPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct MediumFlightRow: View {
    let flight: TrackedFlight

    private var dateText: String {
        flight.departureDate
            .formatted(.dateTime.day().month(.abbreviated))
            .uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(flight.origin)
                    Image(systemName: "airplane")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(flight.destination)
                }
                .font(.system(size: 17, weight: .black, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

                Text(dateText)
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .foregroundStyle(WidgetPalette.muted)
            }

            Spacer(minLength: 4)

            HStack(alignment: .center, spacing: 6) {
                if let price = flight.lastPrice {
                    Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                        .font(.system(size: 16, weight: .heavy, design: .default).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text("—")
                        .font(.system(size: 16, weight: .heavy, design: .default))
                        .foregroundStyle(.white.opacity(0.4))
                }
                DeltaBadge(flight: flight, compact: false)
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
    }
}

// MARK: - Components

private struct DeltaBadge: View {
    let flight: TrackedFlight
    let compact: Bool

    var body: some View {
        if let delta = flight.priceDelta, delta != 0 {
            let isDrop = delta < 0
            let tint = isDrop ? WidgetPalette.dropGreen : WidgetPalette.amber
            let absAmount = delta < 0 ? -delta : delta
            HStack(spacing: 2) {
                Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                    .font(.system(size: compact ? 7 : 8, weight: .bold))
                Text(compactDeltaText(absAmount))
                    .font(.system(size: compact ? 10 : 11, weight: .bold, design: .default).monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.22))
            )
        }
    }

    private func compactDeltaText(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter.string(from: number) ?? number.stringValue
    }
}

private struct EmptyWidgetState: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Spacer(minLength: 0)
            Image(systemName: "airplane.departure")
                .font(.system(size: compact ? 16 : 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("No routes yet")
                .font(.system(size: compact ? 14 : 15, weight: .semibold))
                .foregroundStyle(.white)
            if !compact {
                Text("Open Widfly to add a route.")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetPalette.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct WidflyWidget: Widget {
    let kind = "WidflyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidflyProvider()) { entry in
            WidflyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.navy
                }
        }
        .configurationDisplayName("Flight prices")
        .description("Small shows your cheapest fare. Medium lists upcoming routes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
