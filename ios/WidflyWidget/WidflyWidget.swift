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
                          lastPrice: 5092, previousPrice: 5292, currencyCode: "TRY"),
            TrackedFlight(origin: "IST", destination: "JFK",
                          departureDate: now.addingTimeInterval(86_400 * 50),
                          lastPrice: 18_420, previousPrice: 18_070, currencyCode: "TRY"),
            TrackedFlight(origin: "BJV", destination: "RTM",
                          departureDate: now.addingTimeInterval(86_400 * 25),
                          lastPrice: 5126, previousPrice: 5201, currencyCode: "TRY"),
        ]
    }
}

// MARK: - View

struct WidflyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidflyEntry

    private var upcoming: [TrackedFlight] {
        let cutoff = Calendar.current.startOfDay(for: .now)
        return entry.flights
            .filter { $0.departureDate >= cutoff }
            .sorted { $0.departureDate < $1.departureDate }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        if upcoming.isEmpty {
            emptyState
        } else {
            VStack(spacing: 4) {
                ForEach(upcoming) { flight in
                    FlightCard(flight: flight, family: family)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Image(systemName: "airplane.departure")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("No routes added yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Open Widfly and add a route to start tracking.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card

private struct FlightCard: View {
    let flight: TrackedFlight
    let family: WidgetFamily

    private var compact: Bool { family == .systemSmall }

    private var iataFont: Font {
        .system(size: compact ? 13 : 15, weight: .heavy, design: .monospaced)
    }

    private var arrowSize: CGFloat { compact ? 10 : 11 }

    private var planeSize: CGFloat { compact ? 10 : 12 }

    private var priceFont: Font {
        .system(size: compact ? 14 : 16, weight: .bold, design: .monospaced)
            .monospacedDigit()
    }

    private var dateFont: Font {
        .system(size: compact ? 9 : 11, weight: .medium)
    }

    private var deltaArrowSize: CGFloat { compact ? 7 : 9 }
    private var deltaFont: Font {
        .system(size: compact ? 9 : 10, weight: .semibold, design: .monospaced)
    }

    private static let amber = Color(red: 1.0, green: 0.65, blue: 0.18)
    private static let dropGreen = Color(red: 0.40, green: 0.85, blue: 0.55)

    private var dateText: String {
        flight.departureDate.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Top row: ✈ + IATA pair
            HStack(spacing: compact ? 5 : 7) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: planeSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize()
                Text(flight.origin)
                    .font(iataFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "arrow.right")
                    .font(.system(size: arrowSize, weight: .bold))
                    .foregroundStyle(Self.amber)
                    .fixedSize()
                Text(flight.destination)
                    .font(iataFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }

            // Bottom row: date · Spacer · price · delta
            HStack(alignment: .center, spacing: compact ? 4 : 6) {
                Text(dateText)
                    .font(dateFont)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                priceView
                deltaPill
            }
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 6)
        .background(
            RoundedRectangle(cornerRadius: compact ? 11 : 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 11 : 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                )
        )
    }

    @ViewBuilder
    private var priceView: some View {
        if let price = flight.lastPrice {
            Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                .font(priceFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
        } else {
            Text("—")
                .font(priceFont)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var deltaPill: some View {
        if let delta = flight.priceDelta, delta != 0 {
            let isDrop = delta < 0
            let tint = isDrop ? Self.dropGreen : Self.amber
            let absAmount = delta < 0 ? -delta : delta
            HStack(spacing: 3) {
                Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                    .font(.system(size: deltaArrowSize, weight: .bold))
                Text(PriceFormatting.string(amount: absAmount, currency: flight.currencyCode))
                    .font(deltaFont)
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 5 : 7)
            .padding(.vertical, compact ? 2 : 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Container background

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.18),
                Color(red: 0.03, green: 0.04, blue: 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [Color.purple.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
        )
        .overlay(
            RadialGradient(
                colors: [Color.blue.opacity(0.20), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 220
            )
        )
    }
}

// MARK: - Widget

struct WidflyWidget: Widget {
    let kind = "WidflyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidflyProvider()) { entry in
            WidflyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Flight prices")
        .description("Shows the lowest Skyscanner prices for your saved routes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
