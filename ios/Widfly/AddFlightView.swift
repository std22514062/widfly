import SwiftUI

struct AddFlightView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var origin: String = ""
    @State private var destination: String = ""
    @State private var departureDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var refreshAfterSave = true
    @State private var maxHours: Double = 8
    @State private var limitDuration: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    TextField("Departure Airport (IATA)", text: $origin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Destination Airport (IATA)", text: $destination)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    DatePicker("Date", selection: $departureDate, displayedComponents: .date)
                }

                Section {
                    Toggle("Limit Flight Duration", isOn: $limitDuration)
                    if limitDuration {
                        Stepper(value: $maxHours, in: 2...30, step: 0.5) {
                            HStack {
                                Text("Max Duration")
                                Spacer()
                                Text(durationLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Total time including layovers. Flights exceeding this limit are excluded from the price.")
                }

                Section {
                    Toggle("Fetch Price After Saving", isOn: $refreshAfterSave)
                } footer: {
                    Text("Prices are read by opening the Skyscanner page in WebKit. If a captcha appears, try again in a few minutes.")
                }
            }
            .navigationTitle("New Route")
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
        origin.trimmingCharacters(in: .whitespaces).count == 3
            && destination.trimmingCharacters(in: .whitespaces).count == 3
    }

    private var durationLabel: String {
        let total = Int(maxHours * 60)
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func save() {
        let maxMinutes: Int? = limitDuration ? Int(maxHours * 60) : nil
        model.addFlight(
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            maxDurationMinutes: maxMinutes
        )
        dismiss()
        if refreshAfterSave, let flight = model.flights.last {
            model.refresh(flight: flight)
        }
    }
}
