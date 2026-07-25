import SwiftUI
import WidflyKit

struct EditFlightView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var flight: TrackedFlight
    @State private var origin: String
    @State private var destination: String
    @State private var departureDate: Date
    @State private var limitDuration: Bool
    @State private var maxHours: Double
    @State private var departureTimeFilter: TimeFilter?
    @State private var arrivalTimeFilter: TimeFilter?

    let onSave: (TrackedFlight) -> Void

    init(flight: TrackedFlight, onSave: @escaping (TrackedFlight) -> Void) {
        self._flight = State(initialValue: flight)
        self._origin = State(initialValue: flight.origin)
        self._destination = State(initialValue: flight.destination)
        self._departureDate = State(initialValue: flight.departureDate)
        self._limitDuration = State(initialValue: flight.maxDurationMinutes != nil)
        self._maxHours = State(initialValue: Double(flight.maxDurationMinutes ?? 8 * 60) / 60)
        self._departureTimeFilter = State(initialValue: flight.departureTimeFilter)
        self._arrivalTimeFilter = State(initialValue: flight.arrivalTimeFilter)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        WidflyFormSection("Route & Date") {
                            AirportField(
                                title: "Departure Airport",
                                placeholder: "City, Country, or IATA",
                                text: $origin
                            )
                            WidflyFormDivider()
                            AirportField(
                                title: "Destination Airport",
                                placeholder: "City, Country, or IATA",
                                text: $destination
                            )
                            WidflyFormDivider()
                            DatePicker("Date", selection: $departureDate, in: Date()..., displayedComponents: .date)
                                .tint(Theme.amber)
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                        }

                        WidflyFormSection(
                            "Search Filters",
                            footer: "Widfly picks the cheapest Skyscanner result that matches these filters."
                        ) {
                            WidflyDurationFilter(isEnabled: $limitDuration, maxHours: $maxHours)
                        }

                        WidflyFormSection("Time Filters") {
                            WidflyTimeFilters(
                                departure: $departureTimeFilter,
                                arrival: $arrivalTimeFilter
                            )
                        }

                        WidflyFormSection(
                            "Latest Flight Details",
                            footer: "These fields are filled automatically when Widfly fetches the selected Skyscanner result."
                        ) {
                            airlineReadOnlyRow
                            WidflyFormDivider()
                            readOnlyRow("Departure Time", value: flight.departureTime)
                            WidflyFormDivider()
                            readOnlyRow("Arrival Time", value: flight.arrivalTime)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .foregroundStyle(Theme.amber)
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        AirportLookup.resolve(origin) != nil && AirportLookup.resolve(destination) != nil
    }

    private func save() {
        guard let resolvedOrigin = AirportLookup.resolve(origin),
              let resolvedDestination = AirportLookup.resolve(destination) else { return }

        flight.origin = resolvedOrigin.code
        flight.destination = resolvedDestination.code
        flight.departureDate = departureDate
        flight.maxDurationMinutes = limitDuration ? Int(maxHours * 60) : nil
        flight.departureTimeFilter = departureTimeFilter
        flight.arrivalTimeFilter = arrivalTimeFilter

        onSave(flight)
        dismiss()
    }

    @ViewBuilder
    private var airlineReadOnlyRow: some View {
        let name = flight.airlineName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        HStack {
            Text("Airline Name")
                .foregroundStyle(.white)
            Spacer()
            if name.isEmpty {
                Text("Fetched After Refresh")
                    .foregroundStyle(Theme.mutedText)
            } else {
                HStack(spacing: 8) {
                    AirlineLogo(airlineName: name, size: 22)
                    Text(name)
                        .foregroundStyle(Theme.mutedText)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 13)
    }

    private func readOnlyRow(_ title: String, value: String?) -> some View {
        let displayValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(displayValue?.isEmpty == false ? displayValue! : "Fetched After Refresh")
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
    }
}
