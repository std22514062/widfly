import Foundation
import Observation
import WebKit
import WidflyKit

@MainActor
@Observable
final class SkyscannerDetailSession: Identifiable {
    let id = UUID()
    let webView: WKWebView
    let flight: TrackedFlight

    var statusMessage = "Opening Skyscanner..."
    var resolvedURL: URL?
    var isResolving = false

    private var didTrySelecting = false
    private var pollTask: Task<Void, Never>?

    init(flight: TrackedFlight) {
        self.flight = flight

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        self.webView = WKWebView(frame: .init(x: 0, y: 0, width: 390, height: 800), configuration: configuration)
        self.webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func start() {
        guard !isResolving, resolvedURL == nil else { return }
        isResolving = true

        if let rawURL = flight.bookingURL,
           let url = URL(string: rawURL),
           rawURL.contains("/config/") {
            statusMessage = "Opening selected flight..."
            resolve(url)
        } else {
            statusMessage = "Finding selected flight..."
            webView.load(URLRequest(url: searchURL))
            startAutoSelection()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isResolving = false
        webView.stopLoading()
    }

    private var searchURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.com.tr"
        components.path = "/tasima/ucak-bileti/\(flight.origin.lowercased())/\(flight.destination.lowercased())/\(datePathComponent(flight.departureDate))/"
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "0"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "preferdirects", value: "false")
        ]
        guard let url = components.url else {
            return URL(string: "https://www.skyscanner.com.tr/")!
        }
        return url
    }

    private func datePathComponent(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let y = calendar.component(.year, from: date) % 100
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%02d%02d%02d", y, m, d)
    }

    private func startAutoSelection() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<24 {
                if Task.isCancelled { return }

                if self.resolveCurrentDetailURL() { return }
                if !self.didTrySelecting {
                    _ = await self.trySelectMatchingFlight()
                }

                try? await Task.sleep(for: .milliseconds(500))
            }

            self.statusMessage = "Try again"
            self.isResolving = false
            self.webView.stopLoading()
        }
    }

    private func resolveCurrentDetailURL() -> Bool {
        guard let url = webView.url,
              let detailURL = detailURL(from: url) else {
            return false
        }
        resolve(detailURL)
        return true
    }

    private func resolve(_ url: URL) {
        pollTask?.cancel()
        pollTask = nil
        isResolving = false
        webView.stopLoading()
        resolvedURL = url
    }

    private func detailURL(from url: URL) -> URL? {
        let raw = url.absoluteString
        if raw.contains("/config/") {
            return url
        }

        guard let detailsRange = raw.range(of: "#/details/") else {
            return nil
        }

        let suffix = raw[detailsRange.upperBound...]
        guard let id = suffix.split(separator: "/").first, !id.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.com.tr"
        components.path = "/tasima/ucak-bileti/\(flight.origin.lowercased())/\(flight.destination.lowercased())/\(datePathComponent(flight.departureDate))/config/\(id)"
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "0"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "preferdirects", value: "false")
        ]

        return components.url
    }

    private func trySelectMatchingFlight() async -> Bool {
        guard !didTrySelecting else { return false }

        let script = Self.selectFlightJavaScript(
            departureTime: flight.departureTime,
            arrivalTime: flight.arrivalTime,
            durationMinutes: flight.durationMinutes
        )

        do {
            let value = try await webView.evaluateJavaScript(script)
            if let urlString = value as? String,
               let url = URL(string: urlString),
               urlString.contains("/config/") {
                resolve(url)
                return true
            }

            if let json = value as? String,
               let data = json.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               object["status"] as? String == "clicked" {
                didTrySelecting = true
                statusMessage = "Opening selected flight..."
                return true
            }
        } catch {
            // Skyscanner is still loading; polling will retry.
        }

        return false
    }

    private static func selectFlightJavaScript(
        departureTime: String?,
        arrivalTime: String?,
        durationMinutes: Int?
    ) -> String {
        let departure = departureTime ?? ""
        let arrival = arrivalTime ?? ""
        let duration = durationMinutes.map(String.init) ?? ""

        return """
        (function() {
          if (window.__widflyOpenSelected) return JSON.stringify({ status: 'alreadyClicked' });
          var departure = '\(departure)';
          var arrival = '\(arrival)';
          var duration = '\(duration)';

          function absoluteURL(href) {
            if (!href) return null;
            try { return new URL(href, window.location.href).href; } catch (e) { return null; }
          }

          function durationMatches(text) {
            if (!duration) return true;
            var wanted = parseInt(duration, 10);
            var rx = /(\\d+)\\s*(?:saat|sa\\.?|h\\b)\\s*(?:(\\d+)\\s*(?:dakika|dk\\.?|m\\b))?/gi;
            var m;
            while ((m = rx.exec(text || '')) !== null) {
              var total = parseInt(m[1], 10) * 60 + (m[2] ? parseInt(m[2], 10) : 0);
              if (Math.abs(total - wanted) <= 10) return true;
            }
            return false;
          }

          function configURLIn(node) {
            while (node && node !== document.body) {
              if (node.tagName === 'A') {
                var own = absoluteURL(node.getAttribute('href'));
                if (own && own.indexOf('/config/') >= 0) return own;
              }
              var direct = node.querySelector ? node.querySelector('a[href*="/config/"]') : null;
              if (direct) {
                var directURL = absoluteURL(direct.getAttribute('href'));
                if (directURL) return directURL;
              }
              node = node.parentElement;
            }
            return null;
          }

          function clickDealIn(node) {
            while (node && node !== document.body) {
              var candidates = node.querySelectorAll ? node.querySelectorAll('a, button, [role="button"]') : [];
              for (var i = 0; i < candidates.length; i++) {
                var candidate = candidates[i];
                var text = (candidate.innerText || candidate.textContent || '').replace(/\\s+/g, ' ').trim();
                var href = candidate.getAttribute ? (candidate.getAttribute('href') || '') : '';
                if (href.indexOf('/config/') >= 0 || /teklifleri?\\s*gör|view\\s*deal|select|details|continue/i.test(text)) {
                  window.__widflyOpenSelected = true;
                  candidate.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                  if (typeof candidate.click === 'function') candidate.click();
                  return true;
                }
              }
              node = node.parentElement;
            }
            return false;
          }

          var elements = document.body ? document.body.querySelectorAll('*') : [];
          for (var i = 0; i < elements.length; i++) {
            var el = elements[i];
            var text = el.textContent || '';
            if (text.length < 20 || text.length > 2500) continue;
            if (departure && text.indexOf(departure) < 0) continue;
            if (arrival && text.indexOf(arrival) < 0) continue;
            if (!durationMatches(text)) continue;

            var configURL = configURLIn(el);
            if (configURL) return configURL;
            if (clickDealIn(el)) return JSON.stringify({ status: 'clicked' });
          }

          return JSON.stringify({ status: 'noMatch' });
        })();
        """
    }
}
