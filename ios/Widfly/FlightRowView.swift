import SwiftUI
import WidflyKit

struct FlightRowView: View {
    let flight: TrackedFlight
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let isOpeningSkyscanner: Bool
    let onOpenSkyscanner: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            iataRow
            metaRow
            airlineRow
            itineraryDetails
            priceRow
            bookingLink
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
            Spacer()
        }
        .font(.system(size: 12, weight: .bold, design: .default))
        .foregroundStyle(Theme.mutedText)
        .lineLimit(1)
    }

    @ViewBuilder
    private var airlineRow: some View {
        if let airlineName = flight.airlineName {
            HStack(spacing: 8) {
                airlineLogoPlaceholder
                Text(airlineName)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }

    private var airlineLogoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.white.opacity(0.14))
            .overlay(
                Text(airlineInitial)
                    .font(.system(size: 11, weight: .black, design: .default))
                    .foregroundStyle(Theme.amber)
            )
            .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var itineraryDetails: some View {
        let hasTimes = flight.departureTime != nil || flight.arrivalTime != nil
        let hasStops = flight.stopsSummary != nil
        let hasDuration = flight.fetchedDurationLabel != nil

        if hasTimes || hasStops || hasDuration {
            VStack(alignment: .leading, spacing: 4) {
                if hasTimes {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(flight.departureTime ?? "—") → \(flight.arrivalTime ?? "—")")
                    }
                }

                HStack(spacing: 6) {
                    if let duration = flight.fetchedDurationLabel {
                        Label(duration.uppercased(), systemImage: "timer")
                    }
                    if let stops = flight.stopsSummary {
                        Text(stops)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .font(.system(size: 11, weight: .bold, design: .default))
            .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var priceRow: some View {
        HStack(alignment: .center, spacing: 10) {
            priceView
            deltaPill
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 1) {
                if let previous = flight.previousPrice, previous != price {
                    Text(PriceFormatting.string(amount: previous, currency: flight.currencyCode))
                        .font(.system(size: 12, weight: .bold, design: .default).monospacedDigit())
                        .foregroundStyle(Theme.mutedText)
                        .strikethrough(true, color: Theme.mutedText)
                }
                Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                    .font(.price(size: 26))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
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
    private var bookingLink: some View {
        Button(action: onOpenSkyscanner) {
            HStack(spacing: 7) {
                Image(systemName: "ticket")
                    .font(.system(size: 11, weight: .bold))
                Text(isOpeningSkyscanner ? "Opening Skyscanner..." : "Open on Skyscanner")
                    .font(.system(size: 12, weight: .bold, design: .default))
                Spacer(minLength: 0)
                if isOpeningSkyscanner {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.amber)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.amber.opacity(0.13))
                    .overlay(
                        Capsule(style: .continuous)
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

    private var airlineInitial: String {
        guard let first = flight.airlineName?.first else { return "A" }
        return String(first)
    }
}
