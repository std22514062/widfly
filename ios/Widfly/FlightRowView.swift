import SwiftUI
import WidflyKit

struct FlightRowView: View {
    let flight: TrackedFlight
    let onRefresh: () -> Void

    private var dateText: String {
        flight.departureDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(flight.routeLabel)
                    .font(.headline)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 6) {
                Text(dateText)
                if let limit = flight.maxDurationLabel {
                    Text("·")
                    Text(limit)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let price = flight.lastPrice {
                Text(PriceFormatting.string(amount: price, currency: flight.currencyCode))
                    .font(.title2.bold())

                if let delta = flight.priceDelta, delta != 0 {
                    Text(PriceFormatting.deltaString(delta: delta, currency: flight.currencyCode))
                        .font(.subheadline)
                        .foregroundStyle(delta < 0 ? .green : .orange)
                }

                if let updated = flight.lastUpdated {
                    Text("Updated: \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let error = flight.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Price not fetched yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
