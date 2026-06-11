import SwiftUI
import WidflyKit

struct FlightRowView: View {
    let flight: TrackedFlight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                routeLabel
                Spacer(minLength: 8)
                Text(dateText)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 8) {
                metaLabel
                    .layoutPriority(0)

                Spacer(minLength: 8)

                priceLabel
                    .layoutPriority(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

    private var routeLabel: some View {
        HStack(spacing: 6) {
            Text(flight.origin)
            Image(systemName: "airplane")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(flight.destination)
        }
        .font(.iata(size: 18))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    @ViewBuilder
    private var metaLabel: some View {
        if let error = flight.lastError {
            Label {
                Text(error)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
        } else if !secondaryMeta.isEmpty {
            Text(secondaryMeta)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } else if flight.lastPrice == nil {
            Text("Tap for details")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(Theme.mutedText)
        }
    }

    @ViewBuilder
    private var priceLabel: some View {
        if let price = flight.lastPrice {
            VStack(alignment: .trailing, spacing: 2) {
                if let previous = flight.previousPrice, previous != price {
                    Text(PriceFormatting.string(amount: previous, currency: flight.currencyCode))
                        .font(.system(size: 10, weight: .semibold, design: .default).monospacedDigit())
                        .foregroundStyle(Theme.mutedText)
                        .strikethrough(true, color: Theme.mutedText)
                }

                HStack(alignment: .center, spacing: 5) {
                    if let delta = flight.priceDelta, delta != 0 {
                        let isDrop = delta < 0
                        Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(isDrop ? Theme.dropGreen : Color(red: 0.95, green: 0.30, blue: 0.28))
                    }
                    Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                        .font(.price(size: 20))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        } else if flight.lastError == nil {
            Text("—")
                .font(.price(size: 20))
                .foregroundStyle(Theme.mutedText)
        }
    }

    private var secondaryMeta: String {
        var parts: [String] = []
        if let airline = flight.airlineName {
            parts.append(airline)
        }
        if flight.departureTime != nil || flight.arrivalTime != nil {
            parts.append("\(flight.departureTime ?? "—")–\(flight.arrivalTime ?? "—")")
        }
        return parts.joined(separator: " · ")
    }

    private var dateText: String {
        flight.departureDate
            .formatted(date: .abbreviated, time: .omitted)
            .uppercased()
    }
}
