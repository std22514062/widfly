import Foundation

public enum PriceFormatting {
    public static func string(amount: Decimal, currency: String) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "\(number) \(currency)"
    }

    public static func deltaString(delta: Decimal, currency: String) -> String {
        let prefix = delta < 0 ? "↓" : (delta > 0 ? "↑" : "→")
        let absValue = abs(delta)
        return "\(prefix) \(string(amount: absValue, currency: currency))"
    }
}
