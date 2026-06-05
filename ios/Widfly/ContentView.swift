import SwiftUI
import WidflyKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingAdd = false
    @State private var detailSession: SkyscannerDetailSession?
    @State private var resolvingFlightID: UUID?
    @State private var editMode: EditMode = .inactive
    @State private var editingFlight: TrackedFlight?
    @State private var detailedFlight: TrackedFlight?
    @State private var isListReady = false

    var body: some View {
        @Bindable var model = model

        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .bottom) {
            if !model.flights.isEmpty {
                Text(model.footerText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.background.opacity(0.96))
            }
        }
        .overlay(alignment: .topLeading) {
            if let detailSession {
                SkyscannerExternalOpenerBackgroundView(
                    session: detailSession,
                    onResolved: { url in
                        if let flight = model.flights.first(where: { $0.id == detailSession.flight.id }) {
                            model.updateBookingURL(for: flight, url: url)
                        }
                    },
                    onFinish: {
                        resolvingFlightID = nil
                        self.detailSession = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddFlightView()
        }
        .sheet(item: $editingFlight) { flight in
            EditFlightView(flight: flight) { updated in
                model.updateFlight(updated)
            }
        }
        .sheet(item: $detailedFlight) { flight in
            FlightDetailView(flight: flight)
        }
        .sheet(item: $model.activeSession, onDismiss: {
            model.sessionDidDismiss()
        }) { session in
            RefreshSheetView(session: session)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                CircularGlassButton(
                    systemName: "arrow.clockwise",
                    isLoading: model.isRefreshing,
                    isHidden: model.flights.isEmpty
                ) {
                    model.refreshAll()
                }

                if !model.flights.isEmpty {
                    CircularGlassButton(systemName: editMode == .active ? "checkmark" : "arrow.up.arrow.down") {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }

                Spacer()

                CircularGlassButton(systemName: "plus") {
                    showingAdd = true
                }
            }

            Text("Widfly")
                .font(.system(size: 38, weight: .black, design: .default))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .safeAreaPadding(.top, 8)
        .padding(.bottom, 18)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.flights.isEmpty {
            emptyState
        } else {
            flightList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "airplane")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text("No Routes Yet")
                .font(.system(size: 22, weight: .black, design: .default))
                .foregroundStyle(.white)
            Text("Tap + to track the lowest Skyscanner price for a route and date.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var flightList: some View {
        List {
            ForEach(model.flights) { flight in
                FlightRowView(
                    flight: flight,
                    onRefresh: {
                        model.refresh(flight: flight)
                    },
                    onEdit: {
                        editingFlight = flight
                    },
                    isOpeningSkyscanner: resolvingFlightID == flight.id,
                    onOpenSkyscanner: {
                        if let rawURL = flight.bookingURL,
                           let url = URL(string: rawURL),
                           rawURL.contains("/config/") {
                            openURL(url)
                        } else {
                            resolvingFlightID = flight.id
                            detailSession = SkyscannerDetailSession(flight: flight)
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    detailedFlight = flight
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: model.deleteFlights)
            .onMove(perform: model.moveFlights)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .onAppear { isListReady = true }
        .refreshable {
            guard isListReady, !model.isRefreshing else { return }
            model.refreshAll()
        }
    }
}

// MARK: - Circular glass button

private struct CircularGlassButton: View {
    let systemName: String
    var isLoading: Bool = false
    var isHidden: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.cardFill)
                Circle()
                    .strokeBorder(Theme.cardStroke, lineWidth: 0.8)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.amber)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.amber)
                }
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isHidden ? 0 : 1)
        .accessibilityHidden(isHidden)
    }
}

struct FlightDetailView: View {
    let flight: TrackedFlight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Origin", value: airportName(flight.origin))
                    LabeledContent("Destination", value: airportName(flight.destination))
                    LabeledContent("Date", value: flight.departureDate.formatted(date: .abbreviated, time: .omitted))
                } header: {
                    Text("Route")
                }

                if flight.departureTimeFilter != nil
                    || flight.arrivalTimeFilter != nil
                    || flight.maxDurationMinutes != nil {
                    Section {
                        if let filter = flight.departureTimeFilter {
                            LabeledContent("Departure Window", value: filter.rawValue)
                        } else {
                            LabeledContent("Departure Window", value: "Any Time")
                        }
                        if let filter = flight.arrivalTimeFilter {
                            LabeledContent("Arrival Window", value: filter.rawValue)
                        } else {
                            LabeledContent("Arrival Window", value: "Any Time")
                        }
                        if let maxDuration = flight.maxDurationLabel {
                            LabeledContent("Max Duration", value: maxDuration)
                        }
                    } header: {
                        Text("Search Filters")
                    } footer: {
                        Text("Widfly picks the cheapest Skyscanner result that matches these filters.")
                    }
                }

                if let price = flight.lastPrice {
                    Section {
                        LabeledContent("Current Price", value: PriceFormatting.string(amount: price, currency: flight.currencyCode))
                        if let prev = flight.previousPrice, prev != price {
                            LabeledContent("Previous Price", value: PriceFormatting.string(amount: prev, currency: flight.currencyCode))
                        }
                    } header: {
                        Text("Price Details")
                    }
                }

                Section {
                    if let airline = flight.airlineName {
                        HStack {
                            Text("Airline")
                            Spacer()
                            HStack(spacing: 8) {
                                AirlineLogo(airlineName: airline, size: 20)
                                Text(airline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let dep = flight.departureTime {
                        LabeledContent("Departure", value: dep)
                    }
                    if let arr = flight.arrivalTime {
                        LabeledContent("Arrival", value: arr)
                    }
                    if let dur = flight.fetchedDurationLabel {
                        LabeledContent("Duration", value: dur)
                    }
                    if let stops = flight.stopsSummary {
                        LabeledContent("Stops", value: stops)
                    }
                } header: {
                    Text("Itinerary")
                } footer: {
                    if flight.lastUpdated != nil {
                        Text("These details are extracted from the latest Skyscanner search results.")
                    }
                }
            }
            .navigationTitle("Flight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func airportName(_ code: String) -> String {
        if let resolved = AirportLookup.resolve(code) {
            return "\(resolved.name) (\(code))"
        }
        return code
    }
}
