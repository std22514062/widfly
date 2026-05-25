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
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(storageFileName)
    }

    public static func load() -> [TrackedFlight] {
        let url = storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TrackedFlight].self, from: data)
        } catch {
            return []
        }
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
}
