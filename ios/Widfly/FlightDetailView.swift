import SwiftUI
import WidflyKit

struct FlightDetailView: View {
    let flight: TrackedFlight
    let isOpeningSkyscanner: Bool
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onOpenSkyscanner: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    routeStrip
                    dashboardPanel
                    DetailActionBar(
                        isOpeningSkyscanner: isOpeningSkyscanner,
                        onRefresh: onRefresh,
                        onEdit: onEdit,
                        onOpenSkyscanner: onOpenSkyscanner
                    )
                    if flight.lastUpdated != nil {
                        footerNote
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Flight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var routeStrip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 6) {
                Text(flight.origin)
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(flight.destination)
            }
            .font(.iata(size: 20))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Text(dateText)
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
        }
    }

    private var dashboardPanel: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                DetailPriceHero(flight: flight)

                Rectangle()
                    .fill(Theme.cardStroke)
                    .frame(height: 0.6)

                itinerarySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
    }

    @ViewBuilder
    private var itinerarySection: some View {
        if hasItineraryContent {
            VStack(alignment: .leading, spacing: 12) {
                if flight.departureTime != nil || flight.arrivalTime != nil {
                    HStack(alignment: .center, spacing: 8) {
                        Text(timeRangeText)
                            .font(.system(size: 16, weight: .bold, design: .default).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 8)

                        if let dur = flight.fetchedDurationLabel {
                            Text(dur)
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(Theme.mutedText)
                        }
                    }
                } else if let dur = flight.fetchedDurationLabel {
                    detailRow(label: "Duration", value: dur)
                }

                if let airline = flight.airlineName {
                    HStack(spacing: 10) {
                        AirlineLogo(airlineName: airline, size: 24)
                        Text(airline)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                if let stops = flight.stopsSummary {
                    Text(stops)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        } else if flight.lastError != nil {
            Label {
                Text(flight.lastError ?? "")
                    .lineLimit(3)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
        } else if flight.lastPrice == nil {
            Text("Refresh to load flight details.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mutedText)
        }
    }

    private var footerNote: some View {
        Text("These details are extracted from the latest Skyscanner search results.")
            .font(.footnote)
            .foregroundStyle(Theme.mutedText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var hasItineraryContent: Bool {
        flight.airlineName != nil
            || flight.departureTime != nil
            || flight.arrivalTime != nil
            || flight.fetchedDurationLabel != nil
            || flight.stopsSummary != nil
    }

    private var timeRangeText: String {
        "\(flight.departureTime ?? "—") → \(flight.arrivalTime ?? "—")"
    }

    private var dateText: String {
        flight.departureDate
            .formatted(date: .abbreviated, time: .omitted)
            .uppercased()
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mutedText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Glass card

private struct DetailGlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 0.6)
                    )
            )
    }
}

// MARK: - Price hero

private struct DetailPriceHero: View {
    let flight: TrackedFlight

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            if let price = flight.lastPrice {
                VStack(alignment: .trailing, spacing: 4) {
                    if let previous = flight.previousPrice, previous != price {
                        Text(PriceFormatting.string(amount: previous, currency: flight.currencyCode))
                            .font(.system(size: 13, weight: .semibold, design: .default).monospacedDigit())
                            .foregroundStyle(Theme.mutedText)
                            .strikethrough(true, color: Theme.mutedText)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        if let delta = flight.priceDelta, delta != 0 {
                            let isDrop = delta < 0
                            Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(isDrop ? Theme.dropGreen : Color(red: 0.95, green: 0.30, blue: 0.28))
                        }
                        Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                            .font(.price(size: 34))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            } else {
                Text("—")
                    .font(.price(size: 34))
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }
}

// MARK: - Action bar

private struct DetailActionBar: View {
    let isOpeningSkyscanner: Bool
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onOpenSkyscanner: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            DetailActionButton(title: "Refresh", systemName: "arrow.clockwise", action: onRefresh)
            DetailActionButton(title: "Edit", systemName: "pencil", action: onEdit)
            DetailActionButton(
                title: "Skyscanner",
                systemName: "arrow.up.right.square",
                isLoading: isOpeningSkyscanner,
                isDisabled: isOpeningSkyscanner,
                action: onOpenSkyscanner
            )
        }
    }
}

private struct DetailActionButton: View {
    let title: String
    let systemName: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Theme.cardFill)
                    Circle()
                        .strokeBorder(Theme.cardStroke, lineWidth: 0.8)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.amber)
                            .controlSize(.small)
                    } else {
                        Image(systemName: systemName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                .frame(width: 44, height: 44)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
