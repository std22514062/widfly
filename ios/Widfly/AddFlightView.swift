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
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach($segments) { $segment in
                            WidflyFormSection(
                                segmentTitle(segment),
                                trailing: {
                                    if segments.count > 1 {
                                        Button {
                                            remove(segment)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(Color(red: 1, green: 0.38, blue: 0.35))
                                                .font(.system(size: 18, weight: .bold))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(segmentTitle(segment))")
                                    }
                                },
                                content: {
                                    AirportField(
                                        title: "Departure Airport",
                                        placeholder: "City, Country, or IATA",
                                        text: $segment.origin
                                    )
                                    WidflyFormDivider()
                                    AirportField(
                                        title: "Destination Airport",
                                        placeholder: "City, Country, or IATA",
                                        text: $segment.destination
                                    )
                                    WidflyFormDivider()
                                    dateSelector(for: $segment)
                                    WidflyFormDivider()
                                    WidflyTimeFilters(
                                        departure: $segment.departureTimeFilter,
                                        arrival: $segment.arrivalTimeFilter
                                    )
                                }
                            )
                        }

                        Button {
                            segments.append(FlightSegmentInput())
                        } label: {
                            Label("Add Another Flight", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.amber)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                                        .fill(Theme.cardFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                                                .strokeBorder(Theme.cardStroke, lineWidth: 0.7)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        WidflyFormSection(
                            "Search Filters",
                            footer: "Total time including layovers. Flights exceeding this limit are excluded from the price."
                        ) {
                            WidflyDurationFilter(isEnabled: $limitDuration, maxHours: $maxHours)
                        }

                        WidflyFormSection(
                            "After Saving",
                            footer: "Prices are read by opening the Skyscanner page in WebKit. If a captcha appears, try again in a few minutes."
                        ) {
                            Toggle("Fetch Price After Saving", isOn: $refreshAfterSave)
                                .tint(Theme.amber)
                                .foregroundStyle(.white)
                                .padding(.vertical, 13)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(segments.count > 1 ? "New Itinerary" : "New Route")
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
        segments.allSatisfy { segment in
            AirportLookup.resolve(segment.origin) != nil
                && AirportLookup.resolve(segment.destination) != nil
                && segment.departureDate != nil
        }
    }

    @ViewBuilder
    private func dateSelector(for segment: Binding<FlightSegmentInput>) -> some View {
        Button {
            segment.wrappedValue.isShowingDatePicker.toggle()
        } label: {
            HStack {
                Text("Date")
                    .foregroundStyle(.white)
                Spacer()
                Text(segment.wrappedValue.departureDate?.formatted(date: .abbreviated, time: .omitted) ?? "Select Date")
                    .foregroundStyle(segment.wrappedValue.departureDate == nil ? Theme.mutedText : Theme.amber)
                    .fontWeight(.semibold)
                Image(systemName: segment.wrappedValue.isShowingDatePicker ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.mutedText)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)

        if segment.wrappedValue.isShowingDatePicker {
            WidflyFormDivider()
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
            .tint(Theme.amber)
            .foregroundStyle(.white)
            .padding(.bottom, 8)
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
                maxDurationMinutes: maxMinutes,
                departureTimeFilter: segment.departureTimeFilter,
                arrivalTimeFilter: segment.arrivalTimeFilter
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
    var departureTimeFilter: TimeFilter? = nil
    var arrivalTimeFilter: TimeFilter? = nil
}
