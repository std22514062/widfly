import Foundation

#if canImport(WebKit)
import WebKit

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
            return "No price found for this route."
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
    private let interactiveTimeout: TimeInterval = 300
    private let pollIntervalNanoseconds: UInt64 = 2_000_000_000

    private var targetURL: URL?
    private var sawCaptcha = false
    private var redirectRetries = 0
    private let maxRedirectRetries = 2

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
        return webView!
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

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            configureWebViewIfNeeded()
            guard let webView else {
                continuation.resume(throwing: SkyscannerScraperError.webViewUnavailable)
                return
            }

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

    private func configureWebViewIfNeeded() {
        guard webView == nil else { return }

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

        do {
            let script = Self.extractPriceJavaScript(
                currency: currency,
                maxDurationMinutes: options.maxDurationMinutes
            )
            let value = try await webView.evaluateJavaScript(script)
            let json = value as? String

            if let json,
               let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
               object["blocked"] as? Bool == true {
                if !options.interactive {
                    finish(with: .failure(SkyscannerScraperError.captchaOrBlocked))
                    return
                }
                // In interactive mode, keep polling so user can solve the challenge.
            }
            if let json, let result = SkyscannerPriceParser.parse(json: json, fallbackCurrency: currency) {
                finish(with: .success(result))
            }
        } catch {
            // Ignore transient JS errors; polling will retry.
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

    private static func extractPriceJavaScript(currency: String, maxDurationMinutes: Int?) -> String {
        let safeCurrency = currency.replacingOccurrences(of: "'", with: "")
        let maxValue = maxDurationMinutes.map(String.init) ?? "0"
        return """
    (function() {
      var currency = '\(safeCurrency)';
      var maxMinutes = \(maxValue);

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

      var priceRx = /(?:₺|TL\\b|TRY\\b|\\$|€|£)\\s*[\\d][\\d.,]*|[\\d][\\d.,]*\\s*(?:₺|TL\\b|TRY\\b|\\$|€|£)/gi;
      function pricesIn(text) {
        var out = [];
        var matches = (text || '').match(priceRx) || [];
        for (var i = 0; i < matches.length; i++) {
          var v = parseAmount(matches[i]);
          if (v !== null) out.push(v);
        }
        return out;
      }

      // Matches "4 sa. 36 dk.", "4 saat 36 dakika", "7h 30m".
      var durRxGlobal = /(\\d+)\\s*(?:saat|sa\\.|h\\b)\\s*(?:(\\d+)\\s*(?:dakika|dk\\.|m\\b))?/gi;
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
      var durProbe = /\\d+\\s*(?:saat|sa\\.|h\\b)/i;
      var curProbe = /(?:₺|TL\\b|TRY\\b|\\$|€|£)/i;
      var elements = document.body ? document.body.querySelectorAll('*') : [];
      var cards = [];
      for (var i = 0; i < elements.length; i++) {
        var el = elements[i];
        var t = el.textContent || '';
        if (t.length < 10 || t.length > 2000) continue;
        if (!durProbe.test(t) || !curProbe.test(t)) continue;
        var hasChildBoth = false;
        var children = el.children;
        for (var j = 0; j < children.length; j++) {
          var ct = children[j].textContent || '';
          if (ct.length < 10 || ct.length > 2000) continue;
          if (durProbe.test(ct) && curProbe.test(ct)) { hasChildBoth = true; break; }
        }
        if (!hasChildBoth) cards.push(el);
      }

      var eligible = [];
      for (var k = 0; k < cards.length; k++) {
        var ct2 = cards[k].textContent || '';
        var durs = durationsIn(ct2);
        if (!durs.length) continue;
        var maxDur = Math.max.apply(null, durs);
        if (maxMinutes > 0 && maxDur > maxMinutes) continue;
        var prs = pricesIn(ct2);
        if (!prs.length) continue;
        eligible.push(Math.min.apply(null, prs));
      }

      if (eligible.length) {
        return JSON.stringify({ found: true, amount: Math.min.apply(null, eligible), currency: currency });
      }

      // No card matched the duration constraint. If a constraint was requested,
      // do not fall back to body-wide scan (could return an over-long flight).
      if (maxMinutes > 0) {
        return JSON.stringify({ found: false });
      }

      var bodyPrices = pricesIn(body);
      if (!bodyPrices.length) return JSON.stringify({ found: false });
      return JSON.stringify({ found: true, amount: Math.min.apply(null, bodyPrices), currency: currency });
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
