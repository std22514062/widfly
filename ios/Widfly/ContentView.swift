import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showingAdd = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Group {
                if model.flights.isEmpty {
                    ContentUnavailableView(
                        "No routes yet",
                        systemImage: "airplane",
                        description: Text("Enter origin, destination, and date to track the lowest Skyscanner price.")
                    )
                } else {
                    List {
                        ForEach(model.flights) { flight in
                            FlightRowView(flight: flight) {
                                model.refresh(flight: flight)
                            }
                        }
                        .onDelete(perform: model.deleteFlights)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Widfly")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.flights.isEmpty {
                        Button {
                            model.refreshAll()
                        } label: {
                            if model.isRefreshing {
                                ProgressView()
                            } else {
                                Label("Refresh all", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(model.isRefreshing)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add route", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddFlightView()
            }
            .sheet(item: $model.activeSession, onDismiss: {
                model.sessionDidDismiss()
            }) { session in
                RefreshSheetView(session: session)
            }
            .safeAreaInset(edge: .bottom) {
                if let message = model.statusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
        }
    }
}
