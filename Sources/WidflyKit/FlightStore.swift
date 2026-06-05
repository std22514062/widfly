import Foundation

public enum FlightStore {
    public static let appGroupID = "group.com.widfly.shared"
    public static let storageFileName = "tracked-flights.json"

    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    public static func storageURL() -> URL {
        if let group = containerURL() {
            return group.appendingPathComponent(storageFileName)
        }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent(storageFileName)
        }
        return documents.appendingPathComponent(storageFileName)
    }

    public static func load() -> [TrackedFlight] {
        let url = storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let flights = try decoder.decode([TrackedFlight].self, from: data)
            return sanitize(flights)
        } catch {
            quarantineCorruptStore(at: url)
            return []
        }
    }

    /// Drops duplicate IDs and normalizes codes so SwiftUI lists cannot trap on bad data.
    private static func sanitize(_ flights: [TrackedFlight]) -> [TrackedFlight] {
        var seen = Set<UUID>()
        var result: [TrackedFlight] = []
        result.reserveCapacity(flights.count)

        for var flight in flights {
            guard seen.insert(flight.id).inserted else { continue }
            flight.origin = flight.origin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            flight.destination = flight.destination.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard flight.origin.count == 3, flight.destination.count == 3 else { continue }
            result.append(flight)
        }

        return result
    }

    @discardableResult
    public static func save(_ flights: [TrackedFlight]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(flights)
        let url = storageURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Moves a corrupt JSON file aside so a bad decode cannot break every subsequent launch.
    private static func quarantineCorruptStore(at url: URL) {
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("tracked-flights-corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backup)
    }
}
