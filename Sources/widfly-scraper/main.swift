import Foundation
import WidflyKit

#if os(macOS)
import AppKit
import WebKit

@MainActor
func run() async {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count >= 3 else {
        fputs(
            """
            Usage:   widfly-scraper <ORIGIN> <DESTINATION> <YYYY-MM-DD> [--headless] [--max-hours N]
            Example: widfly-scraper IST AMS 2026-06-15
                     widfly-scraper IST AMS 2026-06-15 --max-hours 8
                     widfly-scraper IST AMS 2026-06-15 --headless --max-hours 10

            Defaults: interactive window, max-hours = 8.

            """,
            stderr
        )
        exit(1)
    }

    let origin = args[0]
    let destination = args[1]
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: args[2]) else {
        fputs("Invalid date. Use YYYY-MM-DD.\n", stderr)
        exit(1)
    }

    let headless = args.contains("--headless")
    var maxHours: Double = 8
    if let i = args.firstIndex(of: "--max-hours"), i + 1 < args.count,
       let v = Double(args[i + 1]) {
        maxHours = v
    }
    var options = SkyscannerSearchOptions.turkey
    options.interactive = !headless
    options.maxDurationMinutes = maxHours > 0 ? Int(maxHours * 60) : nil

    let scraper = SkyscannerWebScraper()
    var window: NSWindow?

    if options.interactive {
        let view = scraper.attachableWebView()
        view.isHidden = false
        let rect = NSRect(x: 100, y: 100, width: 480, height: 820)
        let win = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Widfly · \(origin) → \(destination)"
        win.contentView = view
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    do {
        let result = try await scraper.fetchLowestPrice(
            origin: origin,
            destination: destination,
            departureDate: date,
            options: options
        )
        window?.orderOut(nil)
        print(PriceFormatting.string(amount: result.amount, currency: result.currency))
        exit(0)
    } catch {
        window?.orderOut(nil)
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
Task { await run() }
app.run()
#else
fatalError("widfly-scraper only runs on macOS.")
#endif
