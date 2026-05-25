import Foundation

public struct SkyscannerSearchOptions: Sendable {
    public var marketHost: String
    public var locale: String
    public var currency: String
    public var adults: Int
    public var interactive: Bool
    /// Maximum total flight duration (including layovers) in minutes. `nil` disables the filter.
    public var maxDurationMinutes: Int?

    public init(
        marketHost: String = "www.skyscanner.com.tr",
        locale: String = "tr-TR",
        currency: String = "TRY",
        adults: Int = 1,
        interactive: Bool = false,
        maxDurationMinutes: Int? = nil
    ) {
        self.marketHost = marketHost
        self.locale = locale
        self.currency = currency
        self.adults = max(1, adults)
        self.interactive = interactive
        self.maxDurationMinutes = maxDurationMinutes
    }

    public static let turkey = SkyscannerSearchOptions()

    public static var turkeyInteractive: SkyscannerSearchOptions {
        SkyscannerSearchOptions(interactive: true)
    }
}

public enum SkyscannerURLBuilder {
  public static func flightSearchURL(
    origin: String,
    destination: String,
    departureDate: Date,
    options: SkyscannerSearchOptions = .turkey
  ) -> URL {
    let from = origin.lowercased()
    let to = destination.lowercased()
    let yymmdd = datePathComponent(departureDate)
    var components = URLComponents()
    components.scheme = "https"
    components.host = options.marketHost
    components.path = "/transport/flights/\(from)/\(to)/\(yymmdd)/"
    components.queryItems = [
      URLQueryItem(name: "adults", value: "\(options.adults)"),
      URLQueryItem(name: "adultsv2", value: "\(options.adults)"),
      URLQueryItem(name: "cabinclass", value: "economy"),
      URLQueryItem(name: "children", value: "0"),
      URLQueryItem(name: "infants", value: "0"),
      URLQueryItem(name: "preferdirects", value: "false"),
      URLQueryItem(name: "rtn", value: "0"),
      URLQueryItem(name: "currency", value: options.currency),
      URLQueryItem(name: "locale", value: options.locale),
    ]
    return components.url!
  }

  private static func datePathComponent(_ date: Date) -> String {
    let calendar = Calendar(identifier: .gregorian)
    let y = calendar.component(.year, from: date) % 100
    let m = calendar.component(.month, from: date)
    let d = calendar.component(.day, from: date)
    return String(format: "%02d%02d%02d", y, m, d)
  }
}
