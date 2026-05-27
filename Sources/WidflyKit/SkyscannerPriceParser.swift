import Foundation

public struct SkyscannerPriceResult: Sendable {
    public var amount: Decimal
    public var currency: String
    public var bookingURL: String?
    public var departureTime: String?
    public var arrivalTime: String?
    public var durationMinutes: Int?
    public var stopsSummary: String?
    public var airlineName: String?

    public init(
        amount: Decimal,
        currency: String,
        bookingURL: String? = nil,
        departureTime: String? = nil,
        arrivalTime: String? = nil,
        durationMinutes: Int? = nil,
        stopsSummary: String? = nil,
        airlineName: String? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.bookingURL = bookingURL
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.stopsSummary = stopsSummary
        self.airlineName = airlineName
    }
}

public enum SkyscannerPriceParser {
    /// Parses JSON returned from in-page JavaScript extraction.
    public static func parse(json: String, fallbackCurrency: String = "TRY") -> SkyscannerPriceResult? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let found = object["found"] as? Bool, !found { return nil }

        if let amount = decimal(from: object["amount"]) {
            let currency = (object["currency"] as? String) ?? fallbackCurrency
            return SkyscannerPriceResult(
                amount: amount,
                currency: currency,
                bookingURL: nonEmptyString(from: object["bookingURL"]),
                departureTime: nonEmptyString(from: object["departureTime"]),
                arrivalTime: nonEmptyString(from: object["arrivalTime"]),
                durationMinutes: int(from: object["durationMinutes"]),
                stopsSummary: nonEmptyString(from: object["stopsSummary"]),
                airlineName: nonEmptyString(from: object["airlineName"])
            )
        }

        return nil
    }

    private static func nonEmptyString(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func int(from value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func decimal(from value: Any?) -> Decimal? {
        switch value {
        case let number as NSNumber:
            return number.decimalValue
        case let string as String:
            return parseAmountString(string)
        default:
            return nil
        }
    }

    public static func parseAmountString(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var digits = trimmed
        let allowed = CharacterSet(charactersIn: "0123456789,.")
        digits = String(digits.unicodeScalars.filter { allowed.contains($0) })

        if digits.contains(",") && digits.contains(".") {
            digits = digits.replacingOccurrences(of: ".", with: "")
            digits = digits.replacingOccurrences(of: ",", with: ".")
        } else if digits.contains(",") {
            digits = digits.replacingOccurrences(of: ",", with: ".")
        }

        return Decimal(string: digits)
    }
}
