import Foundation

public struct SkyscannerPriceResult: Sendable {
    public var amount: Decimal
    public var currency: String

    public init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency
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
            return SkyscannerPriceResult(amount: amount, currency: currency)
        }

        return nil
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
