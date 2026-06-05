import SwiftUI
import WidflyKit

struct FlightRowView: View {
    let flight: TrackedFlight
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let isOpeningSkyscanner: Bool
    let onOpenSkyscanner: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            routeSection

            if hasItineraryBand {
                itineraryBand
            }

            priceRow
            bookingLink

            if flight.lastError != nil {
                footerRow
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .strokeBorder(Theme.cardStroke, lineWidth: 0.7)
                )
        )
    }

    // MARK: - Route

    private var routeSection: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                actionButtons
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(flight.origin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }
                Text(flight.destination)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.iata(size: 30))
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                Text(dateText)
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(Theme.mutedText)
                if let duration = flight.fetchedDurationLabel {
                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mutedText.opacity(0.6))
                    Text(duration.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            iconButton(systemName: "pencil", tint: .white.opacity(0.82), fill: .white.opacity(0.10), action: onEdit)
            iconButton(systemName: "arrow.clockwise", tint: Theme.amber, fill: Theme.amber.opacity(0.14), action: onRefresh)
        }
    }

    private func iconButton(systemName: String, tint: Color, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Itinerary

    private var hasItineraryBand: Bool {
        flight.airlineName != nil
            || flight.departureTime != nil
            || flight.arrivalTime != nil
            || flight.stopsSummary != nil
    }

    private var itineraryBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Theme.cardStroke.opacity(0.55))
                .frame(height: 0.5)

            if let airlineName = flight.airlineName {
                HStack(spacing: 8) {
                    AirlineLogo(airlineName: airlineName, size: 24, loadsRemoteImage: false)
                    Text(airlineName)
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 12) {
                if flight.departureTime != nil || flight.arrivalTime != nil {
                    Label {
                        Text("\(flight.departureTime ?? "—") – \(flight.arrivalTime ?? "—")")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }

                if let stops = flight.stopsSummary {
                    Text(stops)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .bold, design: .default))
            .foregroundStyle(Theme.mutedText)
        }
    }

    // MARK: - Price (bottom right)

    @ViewBuilder
    private var priceRow: some View {
        HStack {
            Spacer(minLength: 0)

            if let price = flight.lastPrice {
                VStack(alignment: .trailing, spacing: 3) {
                    if let previous = flight.previousPrice, previous != price {
                        Text(PriceFormatting.string(amount: previous, currency: flight.currencyCode))
                            .font(.system(size: 12, weight: .semibold, design: .default).monospacedDigit())
                            .foregroundStyle(Theme.mutedText)
                            .strikethrough(true, color: Theme.mutedText)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        if let delta = flight.priceDelta, delta != 0 {
                            let isDrop = delta < 0
                            Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(isDrop ? Theme.dropGreen : Color(red: 0.95, green: 0.30, blue: 0.28))
                        }
                        Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                            .font(.price(size: 28))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            } else if flight.lastError != nil {
                Text("Price unavailable")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("No price yet")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Booking & errors

    @ViewBuilder
    private var bookingLink: some View {
        Button(action: onOpenSkyscanner) {
            HStack(spacing: 8) {
                Image(systemName: "ticket")
                    .font(.system(size: 12, weight: .bold))
                Text(isOpeningSkyscanner ? "Opening Skyscanner…" : "Open on Skyscanner")
                    .font(.system(size: 13, weight: .bold, design: .default))
                Spacer(minLength: 0)
                if isOpeningSkyscanner {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.amber)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.amber.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.amber.opacity(0.28), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isOpeningSkyscanner)
    }

    @ViewBuilder
    private var footerRow: some View {
        if let error = flight.lastError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(error)
                    .lineLimit(2)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
        }
    }

    private var dateText: String {
        flight.departureDate
            .formatted(date: .abbreviated, time: .omitted)
            .uppercased()
    }
}
