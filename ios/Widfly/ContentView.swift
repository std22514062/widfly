import SwiftUI
import WidflyKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingAdd = false
    @State private var detailSession: SkyscannerDetailSession?
    @State private var resolvingFlightID: UUID?
    @State private var editingFlight: TrackedFlight?
    @State private var detailedFlight: TrackedFlight?
    @State private var didLoadFlights = false
    @State private var refreshSheetSession: RefreshSession?

    var body: some View {
        @Bindable var model = model

        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !model.flights.isEmpty {
                    footerBar
                }
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
                    onFailure: {
                        openURL(SkyscannerBookingURL.searchURL(for: detailSession.flight))
                        model.statusMessage = "Opened search results in Safari."
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
            FlightDetailView(
                flight: flight,
                isOpeningSkyscanner: resolvingFlightID == flight.id,
                onRefresh: {
                    detailedFlight = nil
                    model.refresh(flight: flight)
                },
                onEdit: {
                    detailedFlight = nil
                    editingFlight = flight
                },
                onOpenSkyscanner: {
                    openSkyscanner(for: flight)
                }
            )
        }
        .sheet(item: $refreshSheetSession, onDismiss: {
            model.sessionDidDismiss()
            refreshSheetSession = nil
        }) { session in
            RefreshSheetView(session: session)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didLoadFlights else { return }
            didLoadFlights = true
            model.reload()
        }
        .onChange(of: model.activeSession?.id) { _, _ in
            refreshSheetSession = model.activeSession
        }
    }

    private func openSkyscanner(for flight: TrackedFlight) {
        if let url = SkyscannerBookingURL.validated(for: flight) {
            openURL(url)
        } else {
            resolvingFlightID = flight.id
            detailSession = SkyscannerDetailSession(flight: flight)
        }
    }

    private var footerBar: some View {
        Text(model.footerText)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.background.opacity(0.96))
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
                    sortMenuButton
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

    private var sortMenuButton: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { model.sortOrder },
                set: { model.setSortOrder($0) }
            )) {
                ForEach(FlightListSort.allCases) { option in
                    Label(option.label, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.cardFill)
                Circle()
                    .strokeBorder(Theme.cardStroke, lineWidth: 0.8)
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.amber)
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
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
            ForEach(model.displayedFlights) { flight in
                FlightRowView(flight: flight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        detailedFlight = flight
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            model.refresh(flight: flight)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .tint(Theme.amber)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingFlight = flight
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 8, for: .scrollContent)
        .refreshable {
            guard didLoadFlights, !model.isRefreshing else { return }
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
    let isOpeningSkyscanner: Bool
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onOpenSkyscanner: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: onRefresh) {
                        Label("Refresh Price", systemImage: "arrow.clockwise")
                    }
                    Button(action: onEdit) {
                        Label("Edit Route", systemImage: "pencil")
                    }
                    Button(action: onOpenSkyscanner) {
                        HStack {
                            Label("Open on Skyscanner", systemImage: "arrow.up.right.square")
                            Spacer(minLength: 0)
                            if isOpeningSkyscanner {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isOpeningSkyscanner)
                }

                Section {
                    LabeledContent("Origin", value: airportName(flight.origin))
                    LabeledContent("Destination", value: airportName(flight.destination))
                    LabeledContent("Date", value: flight.departureDate.formatted(date: .abbreviated, time: .omitted))
                } header: {
                    Text("Route")
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
