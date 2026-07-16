import Foundation

#if canImport(WebKit)
import WebKit

// #region agent log
enum ScrapeDebugLog {
    private static let path = "/Users/cagataykalayci/Desktop/widfly/.cursor/debug-7aa347.log"

    static func write(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: Any] = [:],
        runId: String = "pre-fix"
    ) {
        var payload: [String: Any] = [
            "sessionId": "7aa347",
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8) else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try? handle.close()
        } else {
            try? (line + "\n").write(to: url, atomically: false, encoding: .utf8)
        }
    }
}
// #endregion

public enum SkyscannerScraperError: LocalizedError {
    case webViewUnavailable
    case navigationFailed(String)
    case captchaOrBlocked
    case priceNotFound
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .webViewUnavailable:
            return "Web view could not start."
        case .navigationFailed(let detail):
            return "Page failed to load: \(detail)"
        case .captchaOrBlocked:
            return "Skyscanner blocked access (captcha). Open the app and try again, or wait a few minutes."
        case .priceNotFound:
            return "No flights match your filters for this route."
        case .timedOut:
            return "Timed out while loading the price."
        }
    }
}

@MainActor
public final class SkyscannerWebScraper: NSObject {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<SkyscannerPriceResult, Error>?
    private var pollTask: Task<Void, Never>?
    private var options: SkyscannerSearchOptions = .turkey
    private var startedAt = Date()
    private let headlessTimeout: TimeInterval = 45
    private let interactiveTimeout: TimeInterval = 120
    private let pollIntervalNanoseconds: UInt64 = 2_000_000_000

    private var targetURL: URL?
    private var sawCaptcha = false
    private var redirectRetries = 0
    private let maxRedirectRetries = 2
    private var pollCount = 0
    private var scrapeOrigin = ""
    private var scrapeDestination = ""

    private var effectiveTimeout: TimeInterval {
        options.interactive ? interactiveTimeout : headlessTimeout
    }

    public override init() {
        super.init()
    }

    /// Exposes the underlying WKWebView so UI can attach it to a window/view.
    /// Must be called from the main actor.
    public func attachableWebView() -> WKWebView {
        configureWebViewIfNeeded()
    }

    public func fetchLowestPrice(
        origin: String,
        destination: String,
        departureDate: Date,
        options: SkyscannerSearchOptions = .turkey
    ) async throws -> SkyscannerPriceResult {
        self.options = options
        startedAt = .now

        let url = SkyscannerURLBuilder.flightSearchURL(
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            options: options
        )
        self.targetURL = url
        self.sawCaptcha = false
        self.redirectRetries = 0
        self.pollCount = 0
        self.scrapeOrigin = origin.uppercased()
        self.scrapeDestination = destination.uppercased()

        // #region agent log
        ScrapeDebugLog.write(
            hypothesisId: "H4",
            location: "SkyscannerWebScraper.fetchLowestPrice",
            message: "scrape_started",
            data: [
                "origin": scrapeOrigin,
                "destination": scrapeDestination,
                "maxDurationMinutes": options.maxDurationMinutes as Any,
                "url": url.absoluteString,
            ]
        )
        // #endregion

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let webView = configureWebViewIfNeeded()

            var request = URLRequest(url: url)
            request.timeoutInterval = effectiveTimeout
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            webView.load(request)
            startPolling()
        }
    }

    public func cancel() {
        pollTask?.cancel()
        pollTask = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
        webView?.stopLoading()
    }

    @discardableResult
    private func configureWebViewIfNeeded() -> WKWebView {
        if let webView { return webView }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .init(x: 0, y: 0, width: 390, height: 800), configuration: configuration)
        view.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        view.navigationDelegate = self
        view.isHidden = !options.interactive
        webView = view
        return view
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) > effectiveTimeout {
                    finish(with: .failure(SkyscannerScraperError.timedOut))
                    return
                }
                await evaluatePage()
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        }
    }

    private func evaluatePage() async {
        guard let webView else { return }
        let currency = options.currency
        pollCount += 1
        let pollIndex = pollCount
        let elapsed = Date().timeIntervalSince(startedAt)

        do {
            let script = Self.extractPriceJavaScript(
                currency: currency,
                maxDurationMinutes: options.maxDurationMinutes,
                departureTimeFilter: options.departureTimeFilter?.jsToken,
                arrivalTimeFilter: options.arrivalTimeFilter?.jsToken
            )
            let value = try await webView.evaluateJavaScript(script)
            let json = value as? String

            let object = json.flatMap {
                try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]
            }

            // #region agent log
            if let object {
                ScrapeDebugLog.write(
                    hypothesisId: "H1-H5",
                    location: "SkyscannerWebScraper.evaluatePage",
                    message: "poll_result",
                    data: [
                        "poll": pollIndex,
                        "elapsedSec": elapsed,
                        "route": "\(scrapeOrigin)-\(scrapeDestination)",
                        "found": object["found"] as Any,
                        "amount": object["amount"] as Any,
                        "debugSource": object["debugSource"] as Any,
                        "debugCardCount": object["debugCardCount"] as Any,
                        "debugEligibleCount": object["debugEligibleCount"] as Any,
                        "debugEligibleAmounts": object["debugEligibleAmounts"] as Any,
                        "debugFallbackAmounts": object["debugFallbackAmounts"] as Any,
                        "debugLowestBeforePick": object["debugLowestBeforePick"] as Any,
                        "debugMedianCutoff": object["debugMedianCutoff"] as Any,
                        "airlineName": object["airlineName"] as Any,
                        "explicitNoFlights": object["explicitNoFlights"] as Any,
                    ]
                )
            }
            // #endregion

            if let object,
               object["blocked"] as? Bool == true {
                if !options.interactive {
                    finish(with: .failure(SkyscannerScraperError.captchaOrBlocked))
                    return
                }
                // In interactive mode, keep polling so user can solve the challenge.
            }

            if let object, let found = object["found"] as? Bool, !found {
                if object["explicitNoFlights"] as? Bool == true {
                    finish(with: .failure(SkyscannerScraperError.priceNotFound))
                    return
                }
            }

            if let json, let result = SkyscannerPriceParser.parse(json: json, fallbackCurrency: currency) {
                // #region agent log
                ScrapeDebugLog.write(
                    hypothesisId: "H4",
                    location: "SkyscannerWebScraper.evaluatePage",
                    message: "accepting_price",
                    data: [
                        "poll": pollIndex,
                        "elapsedSec": elapsed,
                        "route": "\(scrapeOrigin)-\(scrapeDestination)",
                        "amount": NSDecimalNumber(decimal: result.amount).stringValue,
                        "debugSource": object?["debugSource"] as Any,
                        "airlineName": result.airlineName as Any,
                    ]
                )
                // #endregion
                finish(with: .success(result))
            }
        } catch {
            // #region agent log
            ScrapeDebugLog.write(
                hypothesisId: "H4",
                location: "SkyscannerWebScraper.evaluatePage",
                message: "poll_js_error",
                data: ["poll": pollIndex, "error": error.localizedDescription]
            )
            // #endregion
        }
    }

    private func finish(with result: Result<SkyscannerPriceResult, Error>) {
        pollTask?.cancel()
        pollTask = nil
        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private static func extractPriceJavaScript(
        currency: String,
        maxDurationMinutes: Int?,
        departureTimeFilter: String?,
        arrivalTimeFilter: String?
    ) -> String {
        let safeCurrency = currency.replacingOccurrences(of: "'", with: "")
        let maxValue = maxDurationMinutes.map(String.init) ?? "0"
        let depFilter = departureTimeFilter ?? ""
        let arrFilter = arrivalTimeFilter ?? ""
        return """
    (function() {
      var currency = '\(safeCurrency)';
      var maxMinutes = \(maxValue);
      var depFilter = '\(depFilter)';
      var arrFilter = '\(arrFilter)';

      function timeMatches(timeStr, filterToken) {
        if (!filterToken) return true;
        if (!timeStr) return false;
        var parts = timeStr.split(':');
        if (parts.length < 2) return true;
        var h = parseInt(parts[0], 10);
        if (isNaN(h)) return true;
        if (filterToken === 'morning') return h >= 6 && h < 12;
        if (filterToken === 'afternoon') return h >= 12 && h < 18;
        if (filterToken === 'evening') return h >= 18 || h < 6;
        return true;
      }

      function parseAmount(text) {
        if (!text) return null;
        var cleaned = String(text).replace(/[^0-9.,]/g, '');
        if (!cleaned) return null;
        var hasComma = cleaned.indexOf(',') >= 0;
        var hasDot = cleaned.indexOf('.') >= 0;
        if (hasComma && hasDot) {
          var lastComma = cleaned.lastIndexOf(',');
          var lastDot = cleaned.lastIndexOf('.');
          if (lastComma > lastDot) cleaned = cleaned.replace(/\\./g, '').replace(',', '.');
          else cleaned = cleaned.replace(/,/g, '');
        } else if (hasComma) {
          var afterComma = cleaned.split(',').pop();
          var commaCount = (cleaned.match(/,/g) || []).length;
          if (commaCount > 1 || afterComma.length === 3) cleaned = cleaned.replace(/,/g, '');
          else cleaned = cleaned.replace(',', '.');
        } else if (hasDot) {
          var afterDot = cleaned.split('.').pop();
          var dotCount = (cleaned.match(/\\./g) || []).length;
          if (dotCount > 1 || afterDot.length === 3) cleaned = cleaned.replace(/\\./g, '');
        }
        var v = parseFloat(cleaned);
        if (isNaN(v) || v <= 20 || v >= 1000000) return null;
        return v;
      }

      function filterReasonablePrices(prices) {
        if (!prices.length) return prices;
        if (currency === 'TRY') {
          var realistic = prices.filter(function(p) { return p >= 1000; });
          if (realistic.length) return realistic;
        }
        return prices;
      }

      var priceRx = /(?:₺|TL\\b|TRY\\b|\\$|€|£)\\s*[\\d][\\d.,]*|[\\d][\\d.,]*\\s*(?:₺|TL\\b|TRY\\b|\\$|€|£)/gi;
      var noiseLineRx = /tasarruf|save\\s+|indirim|discount|coupon|promo|bugün|today\\s+only|per\\s+month|aylık|gecelik|\\/night|otel|hotel|araç|car\\s*hire|baggage|bagaj|ek\\s*ücret|fee|alarm|chart|grafik|takvim/i;

      function allParsedPrices(text) {
        var out = [];
        if (!text) return out;
        priceRx.lastIndex = 0;
        var matches = text.match(priceRx) || [];
        for (var i = 0; i < matches.length; i++) {
          var v = parseAmount(matches[i]);
          if (v !== null) out.push(v);
        }
        return out;
      }

      function pricesFromLines(text) {
        var out = [];
        var lines = (text || '').split(/\\n+/);
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].replace(/\\s+/g, ' ').trim();
          if (!line || line.length > 120) continue;
          if (noiseLineRx.test(line)) continue;
          priceRx.lastIndex = 0;
          var matches = line.match(priceRx) || [];
          for (var j = 0; j < matches.length; j++) {
            var v = parseAmount(matches[j]);
            if (v !== null) out.push(v);
          }
        }
        return out;
      }

      function primaryPriceFromPrices(prices) {
        var prs = filterReasonablePrices(prices.slice()).sort(function(a, b) { return a - b; });
        if (!prs.length) return null;
        while (prs.length > 1 && prs[1] / prs[0] > 1.28) {
          prs.shift();
        }
        return prs[0];
      }

      function primaryPriceFromText(text) {
        var linePrices = pricesFromLines(text);
        if (linePrices.length) return primaryPriceFromPrices(linePrices);
        return primaryPriceFromPrices(allParsedPrices(text));
      }

      function resultsRoot() {
        var selectors = [
          '[data-testid="dayview-root"]',
          '[class*="DayView"]',
          '[class*="day-view"]',
          'main'
        ];
        for (var i = 0; i < selectors.length; i++) {
          var el = document.querySelector(selectors[i]);
          if (el) return el;
        }
        return document.body;
      }

      function cardPrimaryPrice(el) {
        if (!el) return null;
        var node = el;
        var depth = 0;
        while (node && node !== document.body && depth <= 4) {
          var linePrices = pricesFromLines(node.textContent || '');
          var rawPrices = linePrices.length ? linePrices : allParsedPrices(node.textContent || '');
          var p = primaryPriceFromPrices(rawPrices);
          if (p !== null) return p;
          node = node.parentElement;
          depth++;
        }
        return null;
      }

      function pickBestEligible(eligible) {
        if (!eligible.length) return { best: null, debug: {} };
        eligible.sort(function(a, b) { return a.amount - b.amount; });
        if (eligible.length === 1) {
          return {
            best: eligible[0],
            debug: {
              debugEligibleAmounts: [eligible[0].amount],
              debugLowestBeforePick: eligible[0].amount,
              debugMedianCutoff: null,
              debugPickAdjusted: false
            }
          };
        }
        var amounts = eligible.map(function(e) { return e.amount; }).sort(function(a, b) { return a - b; });
        var median = amounts[Math.floor(amounts.length / 2)];
        var cutoff = median * 0.68;
        var picked = eligible[0];
        var adjusted = false;
        if (eligible[0].amount < cutoff) {
          for (var i = 0; i < eligible.length; i++) {
            if (eligible[i].amount >= cutoff) {
              picked = eligible[i];
              adjusted = true;
              break;
            }
          }
        }
        return {
          best: picked,
          debug: {
            debugEligibleAmounts: amounts,
            debugLowestBeforePick: eligible[0].amount,
            debugMedianCutoff: cutoff,
            debugPickAdjusted: adjusted
          }
        };
      }

      // Matches "4 sa. 36 dk.", "4 sa 36 dk", "4 saat 36 dakika", "7h 30m".
      var durRxGlobal = /(\\d+)\\s*(?:saat|sa\\.?|h\\b)\\s*(?:(\\d+)\\s*(?:dakika|dk\\.?|m\\b))?/gi;
      function durationsIn(text) {
        var out = [];
        if (!text) return out;
        durRxGlobal.lastIndex = 0;
        var m;
        while ((m = durRxGlobal.exec(text)) !== null) {
          var h = parseInt(m[1], 10);
          var mins = m[2] ? parseInt(m[2], 10) : 0;
          if (!isNaN(h) && h <= 48) out.push(h * 60 + mins);
        }
        return out;
      }

      var body = document.body ? document.body.innerText : '';

      if (/captcha|robot|px-captcha|are you a person/i.test(body)) {
        return JSON.stringify({ found: false, blocked: true });
      }

      // Detect "ticket card" leaf containers: elements whose textContent has
      // both a duration and a currency reference, but no child does. These are
      // the smallest DOM nodes that fully describe a single Skyscanner result.
      var durProbe = /\\d+\\s*(?:saat|sa\\.?|h\\b)/i;
      var curProbe = /(?:₺|TL\\b|TRY\\b|\\$|€|£)/i;
      var sortSummaryProbe = /(?:best|cheapest|fastest)\\s+(?:flight|uçuş)|(?:en\\s+iyi|en\\s+ucuz|en\\s+hızlı)|sıralay(?:ın|in)?|sort\\s+by/i;
      var resultCardProbe = /teklif|offer|view\\s*deal|aktarma|aktarmasız|stop|direkt|direct|nonstop/i;
      var elements = document.body ? document.body.querySelectorAll('*') : [];
      var strictCards = [];
      var fallbackCards = [];
      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var t = el.textContent || '';
        if (t.length < 10 || t.length > 2000) continue;
        if (!durProbe.test(t) || !curProbe.test(t)) continue;
        if (sortSummaryProbe.test(t)) continue;
        var hasChildBoth = false;
        var children = el.children;
        for (var j = 0; j < children.length; j++) {
          var ct = children[j].textContent || '';
          if (ct.length < 10 || ct.length > 2000) continue;
          if (durProbe.test(ct) && curProbe.test(ct)) { hasChildBoth = true; break; }
        }
        if (!hasChildBoth) {
          if (resultCardProbe.test(t)) strictCards.push(el);
          else fallbackCards.push(el);
        }
      }
      var cards = strictCards.length ? strictCards : fallbackCards;

      function absoluteURL(href) {
        if (!href) return null;
        try { return new URL(href, window.location.href).href; } catch (e) { return null; }
      }

      function bookingURLFor(el) {
        var node = el;
        while (node && node !== document.body) {
          if (node.tagName === 'A') {
            var own = absoluteURL(node.getAttribute('href'));
            if (own && own.indexOf('/config/') >= 0) return own;
          }
          var descendant = node.querySelector ? node.querySelector('a[href*="/config/"]') : null;
          if (descendant) {
            var desc = absoluteURL(descendant.getAttribute('href'));
            if (desc) return desc;
          }
          node = node.parentElement;
        }
        return null;
      }

      function timesIn(text) {
        var matches = (text || '').match(/\\b(?:[01]?\\d|2[0-3]):[0-5]\\d\\b/g) || [];
        var unique = [];
        for (var i = 0; i < matches.length; i++) {
          if (unique.indexOf(matches[i]) < 0) unique.push(matches[i]);
        }
        return unique;
      }

      function stopsSummaryIn(text) {
        var rawLines = (text || '').split(/\\n+/);
        var lines = [];
        for (var i = 0; i < rawLines.length; i++) {
          var line = rawLines[i].replace(/\\s+/g, ' ').trim();
          if (!line || line.length > 90) continue;
          priceRx.lastIndex = 0;
          if (priceRx.test(line)) { priceRx.lastIndex = 0; continue; }
          if (/aktarma|stop|direct|direkt|nonstop|havaliman|airport|change/i.test(line)) lines.push(line);
        }
        return lines.length ? lines.slice(0, 2).join(' · ') : null;
      }

      function airlineNameIn(text) {
        var known = [
          'AJet',
          'Pegasus Airlines',
          'Turkish Airlines',
          'SunExpress',
          'KLM',
          'Transavia',
          'Lufthansa',
          'British Airways',
          'Air France',
          'Qatar Airways',
          'Emirates',
          'easyJet',
          'Ryanair'
        ];
        for (var i = 0; i < known.length; i++) {
          if ((text || '').indexOf(known[i]) >= 0) return known[i];
        }
        var rawLines = (text || '').split(/\\n+/);
        for (var j = 0; j < rawLines.length; j++) {
          var line = rawLines[j].replace(/\\s+/g, ' ').trim();
          if (!line || line.length > 45) continue;
          if (/airlines?|airways?|jet|express|transavia|pegasus|lufthansa|klm/i.test(line)) return line;
        }
        return null;
      }

      var eligible = [];
      for (var k = 0; k < cards.length; k++) {
        var card = cards[k];
        var ct2 = card.textContent || '';
        var durs = durationsIn(ct2);
        var amount = cardPrimaryPrice(card);
        if (!durs.length) continue;
        var maxDur = Math.max.apply(null, durs);
        if (maxMinutes > 0 && maxDur > maxMinutes) continue;
        if (amount === null) continue;
        var cardTimes = timesIn(ct2);
        var dTime = cardTimes.length > 0 ? cardTimes[0] : null;
        var aTime = cardTimes.length > 1 ? cardTimes[1] : null;
        if (!timeMatches(dTime, depFilter)) continue;
        if (!timeMatches(aTime, arrFilter)) continue;
        
        eligible.push({
          amount: amount,
          currency: currency,
          durationMinutes: maxDur,
          departureTime: cardTimes.length > 0 ? cardTimes[0] : null,
          arrivalTime: cardTimes.length > 1 ? cardTimes[1] : null,
          stopsSummary: stopsSummaryIn(ct2),
          airlineName: airlineNameIn(ct2),
          bookingURL: bookingURLFor(card),
          cardIndex: k
        });
      }

      if (eligible.length) {
        var pick = pickBestEligible(eligible);
        var best = pick.best;
        best.found = true;
        best.debugSource = 'eligible';
        best.debugCardCount = cards.length;
        best.debugStrictCount = strictCards.length;
        best.debugEligibleCount = eligible.length;
        best.debugEligibleAmounts = pick.debug.debugEligibleAmounts;
        best.debugLowestBeforePick = pick.debug.debugLowestBeforePick;
        best.debugMedianCutoff = pick.debug.debugMedianCutoff;
        best.debugPickAdjusted = pick.debug.debugPickAdjusted;
        delete best.cardIndex;
        return JSON.stringify(best);
      }

      var fallbackAmounts = [];
      for (var fb = 0; fb < cards.length; fb++) {
        var fa = cardPrimaryPrice(cards[fb]);
        if (fa !== null) fallbackAmounts.push(fa);
      }
      if (fallbackAmounts.length) {
        var fbBest = primaryPriceFromPrices(fallbackAmounts);
        if (fbBest !== null) {
          return JSON.stringify({
            found: true,
            amount: fbBest,
            currency: currency,
            debugSource: 'fallback_cards',
            debugCardCount: cards.length,
            debugStrictCount: strictCards.length,
            debugEligibleCount: 0,
            debugFallbackAmounts: fallbackAmounts
          });
        }
      }

      var root = resultsRoot();
      var scopedPrimary = primaryPriceFromText(root ? (root.innerText || '') : body);
      var scopedFrom = 'scoped_primary';
      if (scopedPrimary === null) {
        scopedPrimary = primaryPriceFromText(body);
        scopedFrom = 'body_primary';
      }
      if (scopedPrimary !== null) {
        return JSON.stringify({
          found: true,
          amount: scopedPrimary,
          currency: currency,
          debugSource: scopedFrom,
          debugCardCount: cards.length,
          debugStrictCount: strictCards.length,
          debugEligibleCount: 0
        });
      }

      // Check if Skyscanner explicitly says no flights found
      var noFlightsRx = /maalesef|üzgünüz|bulamadık|no\\s*flights|couldn'?t\\s*find|0\\s*sonuç|0\\s*result/i;
      if (noFlightsRx.test(body)) {
        return JSON.stringify({ found: false, explicitNoFlights: true });
      }

      // Results loaded but none matched duration/time filters — fail fast.
      if (cards.length > 0 && (maxMinutes > 0 || depFilter || arrFilter)) {
        return JSON.stringify({ found: false, explicitNoFlights: true });
      }

      return JSON.stringify({ found: false });
    })();
    """
    }
}

extension SkyscannerWebScraper: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if recoverIfBouncedAwayFromTarget(webView: webView) { return }
        Task { await evaluatePage() }
    }

    /// After PerimeterX captcha is solved Skyscanner redirects to "/" instead of
    /// the original flight search URL. Detect that bounce and re-navigate so the
    /// poll loop can actually find prices.
    private func recoverIfBouncedAwayFromTarget(webView: WKWebView) -> Bool {
        guard let targetURL else { return false }
        let current = webView.url?.absoluteString ?? ""
        let isOnFlightPage = current.contains("/transport/flights/")
        let isOnCaptcha = current.contains("/sttc/px/") || current.contains("/px/captcha")
        let isBlank = current.isEmpty || current == "about:blank"

        guard sawCaptcha,
              !isOnFlightPage,
              !isOnCaptcha,
              !isBlank,
              redirectRetries < maxRedirectRetries
        else { return false }

        redirectRetries += 1
        webView.load(URLRequest(url: targetURL))
        return true
    }

    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(with: .failure(SkyscannerScraperError.navigationFailed(error.localizedDescription)))
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        finish(with: .failure(SkyscannerScraperError.navigationFailed(error.localizedDescription)))
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let rawURL = navigationAction.request.url?.absoluteString ?? ""
        let lowered = rawURL.lowercased()
        let isCaptcha = lowered.contains("captcha") || lowered.contains("/px/")
        if isCaptcha { sawCaptcha = true }

        if isCaptcha && !options.interactive {
            finish(with: .failure(SkyscannerScraperError.captchaOrBlocked))
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

#else

public enum SkyscannerScraperError: LocalizedError {
    case webViewUnavailable

    public var errorDescription: String? {
        "WebKit is not available on this platform."
    }
}

@MainActor
public final class SkyscannerWebScraper: NSObject {
    public func fetchLowestPrice(
        origin: String,
        destination: String,
        departureDate: Date,
        options: SkyscannerSearchOptions = .turkey
    ) async throws -> SkyscannerPriceResult {
        throw SkyscannerScraperError.webViewUnavailable
    }

    public func cancel() {}
}

#endif
