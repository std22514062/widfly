# Widfly

**Track flight prices on your iPhone — right from the Home Screen.**

Widfly helps you monitor the lowest fare for routes you care about. Save a departure, destination, and date; refresh when you want an update; and see prices at a glance in a native iOS widget.

Built with SwiftUI, WidgetKit, and a shared Swift package (`WidflyKit`).

---

## Features

- **Route tracking** — Save one-way routes with IATA airport codes and departure dates
- **Smart filters** — Optional max duration, departure window, and arrival window
- **Price history** — See current price, previous price, and change at a glance
- **Airline details** — Carrier name, times, duration, and stops after a successful refresh
- **Home Screen widget** — Small and medium widgets for upcoming routes (iOS 17+)
- **Direct booking link** — Open the matched itinerary on Skyscanner when you are ready to book
- **Dark, polished UI** — Designed for quick scanning and daily check-ins

---

## How it works

1. Tap **+** to add a route (origin, destination, date, optional filters).
2. Tap **refresh** on a card or use the header control to update all routes.
3. Widfly loads the Skyscanner search page in an in-app session, reads the lowest matching fare, and saves it locally.
4. Your widget reads the same saved data via an App Group and updates after a refresh.

If Skyscanner shows a security challenge (captcha), complete it in the sheet — Widfly continues once the page loads normally.

---

## Requirements

| | |
|---|---|
| **iOS** | 17.0 or later |
| **Device** | iPhone |
| **Build** | macOS with Xcode 15+ (for development) |
| **Account** | Apple Developer account for App Store distribution |

---

## Development setup

### 1. Generate the Xcode project

```bash
brew install xcodegen   # if needed
cd widfly
xcodegen generate
open Widfly.xcodeproj
```

### 2. Signing & capabilities

In Xcode, for both **Widfly** and **WidflyWidgetExtension**:

- Select your **Team**
- Enable **App Groups** → `group.com.widfly.shared`

### 3. Run on device

Connect your iPhone, select it as the run destination, and press **Run**.  
Add the widget from the Home Screen: **Widfly → Flight prices**.

### Optional: command-line price check (macOS)

```bash
swift run widfly-scraper IST AMS 2026-06-15
swift run widfly-scraper IST AMS 2026-06-15 --max-hours 8
```

---

## Project structure

| Target / package | Role |
|------------------|------|
| `WidflyKit` | Models, persistence, Skyscanner URL building, price extraction |
| `Widfly` | Main iOS app (SwiftUI) |
| `WidflyWidgetExtension` | WidgetKit timeline and views |
| `widfly-scraper` | macOS CLI for local debugging |

Price selection logic: search results are evaluated against your filters; ineligible itineraries are ignored; the **lowest eligible fare** is stored.

---

## Widget behavior

The widget displays saved routes and the last known prices. It does **not** fetch prices on its own. Open the app and refresh to update widget data.

---

## Third-party services & disclosure

Widfly is **not affiliated with, endorsed by, or sponsored by Skyscanner**.  
Prices and itinerary details are obtained by loading Skyscanner’s public search experience on behalf of the user, similar to browsing in Safari. Booking always happens on Skyscanner via the in-app link.

**Do you need to say “scraper” in your README or App Store listing?**  
No — and you generally should not lead with technical implementation in user-facing copy. Describe the **outcome** (“tracks Skyscanner prices”, “opens results on Skyscanner”) rather than the mechanism.

**What you should disclose (recommended for App Store):**

- A **Privacy Policy** explaining what is stored on-device (routes, prices, timestamps) and that searches interact with Skyscanner
- Clear attribution that Skyscanner is a third-party service and trademarks belong to their owners
- That prices are indicative and may change before booking

**If you omit technical details entirely:**  
Most consumer apps do. Users care that prices update and that booking works. Omitting “scraper” does not remove legal or platform obligations — Skyscanner’s terms of use and Apple’s guidelines still apply. Avoid claiming an official partnership or guaranteed accuracy.

---

## Known limitations

- Prices refresh only when you trigger a refresh in the app (or when a future background refresh feature is added)
- Skyscanner may show captcha or rate limiting; occasional manual verification is expected
- Third-party site layout changes may require an app update to restore price extraction
- Widget timelines refresh on a schedule but reflect last in-app fetch time

---

## Roadmap ideas

- Background refresh on a user-defined schedule
- Price-drop notifications
- Price history charts

---

## License

Copyright © 2026 Çağatay Kalaycı. All rights reserved.

For distribution terms, add a `LICENSE` file before open-sourcing or publishing.
