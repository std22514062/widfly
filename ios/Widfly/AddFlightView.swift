import SwiftUI
import WidflyKit

struct AddFlightView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var segments: [FlightSegmentInput] = [FlightSegmentInput()]
    @State private var refreshAfterSave = true
    @State private var maxHours: Double = 8
    @State private var limitDuration: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                ForEach($segments) { $segment in
                    Section {
                        AirportField(
                            title: "Departure Airport",
                            placeholder: "City, Country, or IATA",
                            text: $segment.origin
                        )
                        AirportField(
                            title: "Destination Airport",
                            placeholder: "City, Country, or IATA",
                            text: $segment.destination
                        )
                        dateSelector(for: $segment)
                    } header: {
                        HStack {
                            Text(segmentTitle(segment))
                            Spacer()
                            if segments.count > 1 {
                                Button {
                                    remove(segment)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        segments.append(FlightSegmentInput())
                    } label: {
                        Label("Add Another Flight", systemImage: "plus.circle")
                    }
                } footer: {
                    Text("Use this for multi-city trips. Each segment is tracked as its own route.")
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
            .navigationTitle(segments.count > 1 ? "New Itinerary" : "New Route")
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
        segments.allSatisfy { segment in
            AirportLookup.resolve(segment.origin) != nil
                && AirportLookup.resolve(segment.destination) != nil
                && segment.departureDate != nil
        }
    }

    private var durationLabel: String {
        let total = Int(maxHours * 60)
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    @ViewBuilder
    private func dateSelector(for segment: Binding<FlightSegmentInput>) -> some View {
        Button {
            segment.wrappedValue.isShowingDatePicker.toggle()
        } label: {
            HStack {
                Text("Date")
                Spacer()
                Text(segment.wrappedValue.departureDate?.formatted(date: .abbreviated, time: .omitted) ?? "Select Date")
                    .foregroundStyle(segment.wrappedValue.departureDate == nil ? .secondary : .primary)
            }
        }

        if segment.wrappedValue.isShowingDatePicker {
            DatePicker(
                "",
                selection: Binding(
                    get: { segment.wrappedValue.departureDate ?? segment.wrappedValue.draftDate },
                    set: { newDate in
                        segment.wrappedValue.departureDate = newDate
                        segment.wrappedValue.draftDate = newDate
                        segment.wrappedValue.isShowingDatePicker = false
                    }
                ),
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
    }

    private func segmentTitle(_ segment: FlightSegmentInput) -> String {
        guard segments.count > 1,
              let index = segments.firstIndex(where: { $0.id == segment.id }) else {
            return "Route"
        }
        return "Flight \(index + 1)"
    }

    private func remove(_ segment: FlightSegmentInput) {
        guard segments.count > 1 else { return }
        segments.removeAll { $0.id == segment.id }
    }

    private func save() {
        let maxMinutes: Int? = limitDuration ? Int(maxHours * 60) : nil
        let addedFlights = segments.compactMap { segment -> TrackedFlight? in
            guard let origin = AirportLookup.resolve(segment.origin),
                  let destination = AirportLookup.resolve(segment.destination),
                  let departureDate = segment.departureDate else {
                return nil
            }
            return model.addFlight(
                origin: origin.code,
                destination: destination.code,
                departureDate: departureDate,
                maxDurationMinutes: maxMinutes
            )
        }
        dismiss()
        if refreshAfterSave {
            model.refresh(flights: addedFlights)
        }
    }
}

private struct FlightSegmentInput: Identifiable, Equatable {
    let id = UUID()
    var origin: String = ""
    var destination: String = ""
    var departureDate: Date?
    var draftDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    var isShowingDatePicker = false
}

struct AirportField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    private var suggestions: [Airport] {
        AirportLookup.suggestions(for: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               AirportLookup.resolve(text)?.code != text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                ForEach(suggestions) { airport in
                    Button {
                        text = airport.code
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airport.displayTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(airport.displaySubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel(title)
    }
}
