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
                          lastPrice: 5092, currencyCode: "TRY"),
            TrackedFlight(origin: "IST", destination: "JFK",
                          departureDate: now.addingTimeInterval(86_400 * 50),
                          lastPrice: 18_420, currencyCode: "TRY"),
            TrackedFlight(origin: "BJV", destination: "RTM",
                          departureDate: now.addingTimeInterval(86_400 * 25),
                          lastPrice: 5126, currencyCode: "TRY"),
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
        VStack(alignment: .leading, spacing: family == .systemMedium ? 10 : 8) {
            HStack {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }

            if upcoming.isEmpty {
                emptyState
            } else {
                VStack(spacing: family == .systemMedium ? 8 : 6) {
                    ForEach(upcoming) { flight in
                        FlightCard(flight: flight, family: family)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
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
        .system(size: compact ? 15 : 19, weight: .heavy, design: .monospaced)
    }

    private var arrowSize: CGFloat { compact ? 11 : 14 }

    private var priceFont: Font {
        .system(size: compact ? 16 : 20, weight: .bold, design: .monospaced)
            .monospacedDigit()
    }

    private var dateFont: Font {
        .system(size: compact ? 11 : 13, weight: .medium)
    }

    private var dateText: String {
        flight.departureDate.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 6 : 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: compact ? 4 : 6) {
                    Text(flight.origin)
                        .font(iataFont)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "arrow.right")
                        .font(.system(size: arrowSize, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.65, blue: 0.18))
                        .fixedSize()
                    Text(flight.destination)
                        .font(iataFont)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text(dateText)
                    .font(dateFont)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if let price = flight.lastPrice {
                Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                    .font(priceFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            } else {
                Text("—")
                    .font(priceFont)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                )
        )
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
