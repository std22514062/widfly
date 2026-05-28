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
            Form {
                Section("Route") {
                    AirportField(
                        title: "Departure Airport",
                        placeholder: "City, Country, or IATA",
                        text: $origin
                    )
                    AirportField(
                        title: "Destination Airport",
                        placeholder: "City, Country, or IATA",
                        text: $destination
                    )
                    DatePicker("Date", selection: $departureDate, displayedComponents: .date)
                }

                Section {
                    readOnlyRow("Airline Name", value: flight.airlineName)
                    readOnlyRow("Departure Time", value: flight.departureTime)
                    readOnlyRow("Arrival Time", value: flight.arrivalTime)
                } header: {
                    Text("Flight Details")
                } footer: {
                    Text("These fields are filled automatically when Widfly fetches the selected Skyscanner result.")
                }

                Section {
                    Toggle("Limit Flight Duration", isOn: $limitDuration)
                    if limitDuration {
                        Stepper(value: $maxHours, in: 2...30, step: 0.5) {
                            HStack {
                                Text("Max Duration")
                                Spacer()
                                Text(maxDurationLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Time Filters") {
                    Picker("Departure Time", selection: $departureTimeFilter) {
                        Text("Any Time").tag(TimeFilter?.none)
                        ForEach(TimeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(TimeFilter?.some(filter))
                        }
                    }
                    Picker("Arrival Time", selection: $arrivalTimeFilter) {
                        Text("Any Time").tag(TimeFilter?.none)
                        ForEach(TimeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(TimeFilter?.some(filter))
                        }
                    }
                }
            }
            .navigationTitle("Edit Flight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        AirportLookup.resolve(origin) != nil && AirportLookup.resolve(destination) != nil
    }

    private var maxDurationLabel: String {
        let total = Int(maxHours * 60)
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
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

    private func readOnlyRow(_ title: String, value: String?) -> some View {
        let displayValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack {
            Text(title)
            Spacer()
            Text(displayValue?.isEmpty == false ? displayValue! : "Fetched After Refresh")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
