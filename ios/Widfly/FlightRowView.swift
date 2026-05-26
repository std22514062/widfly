import SwiftUI
import WidflyKit

struct FlightRowView: View {
    let flight: TrackedFlight
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            iataRow
            metaRow
            priceRow
            footerRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
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

    // MARK: - Rows

    private var iataRow: some View {
        HStack(spacing: 12) {
            Text(flight.origin)
                .font(.iata(size: 26))
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 4)
            Image(systemName: "airplane")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize()
            Spacer(minLength: 4)
            Text(flight.destination)
                .font(.iata(size: 26))
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(dateText)
            if let limit = flight.maxDurationLabel {
                Text("·")
                Text(limit.uppercased())
            }
            Spacer()
        }
        .font(.system(size: 12, weight: .bold, design: .default))
        .foregroundStyle(Theme.mutedText)
        .lineLimit(1)
    }

    private var priceRow: some View {
        HStack(alignment: .center, spacing: 10) {
            priceView
            deltaPill
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Theme.amber.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var priceView: some View {
        if let price = flight.lastPrice {
            Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                .font(.price(size: 26))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if flight.lastError != nil {
            Text("—")
                .font(.price(size: 26))
                .foregroundStyle(.white.opacity(0.4))
        } else {
            Text("—")
                .font(.price(size: 26))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var deltaPill: some View {
        if let delta = flight.priceDelta, delta != 0 {
            let isDrop = delta < 0
            let tint = isDrop ? Theme.dropGreen : Theme.amber
            let absAmount = delta < 0 ? -delta : delta
            HStack(spacing: 4) {
                Image(systemName: isDrop ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(PriceFormatting.string(amount: absAmount, currency: flight.currencyCode))
                    .font(.system(size: 12, weight: .bold, design: .default).monospacedDigit())
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.16))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(tint.opacity(0.35), lineWidth: 0.6)
                    )
            )
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        if let error = flight.lastError {
            Text(error)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
                .lineLimit(2)
        } else if let updated = flight.lastUpdated {
            Text("Updated \(updated.formatted(date: .omitted, time: .shortened))".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.mutedText)
                .tracking(0.5)
        } else if flight.lastPrice == nil {
            Text("Tap refresh to fetch price".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.mutedText)
                .tracking(0.5)
        }
    }

    // MARK: - Helpers

    private var dateText: String {
        flight.departureDate
            .formatted(date: .abbreviated, time: .omitted)
            .uppercased()
    }
}
