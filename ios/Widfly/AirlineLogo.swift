import SwiftUI

enum AirlineBrandResolver {
    static func domain(for airlineName: String) -> String? {
        let lower = airlineName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !lower.isEmpty else { return nil }

        let mappings: [(keywords: [String], domain: String)] = [
            (["turkish airlines", "turkish", "thy"], "turkishairlines.com"),
            (["pegasus"], "flypgs.com"),
            (["ajet"], "ajet.com"),
            (["sunexpress", "sun express"], "sunexpress.com"),
            (["corendon"], "corendon.com"),
            (["klm"], "klm.com"),
            (["lufthansa"], "lufthansa.com"),
            (["british airways", "british"], "britishairways.com"),
            (["air france"], "airfrance.com"),
            (["qatar"], "qatarairways.com"),
            (["emirates"], "emirates.com"),
            (["easyjet"], "easyjet.com"),
            (["ryanair"], "ryanair.com"),
            (["transavia"], "transavia.com"),
            (["wizz"], "wizzair.com"),
            (["vueling"], "vueling.com"),
            (["iberia"], "iberia.com"),
            (["swiss"], "swiss.com"),
            (["austrian"], "austrian.com"),
            (["brussels airlines"], "brusselsairlines.com"),
            (["eurowings"], "eurowings.com"),
            (["norwegian"], "norwegian.com"),
            (["finnair"], "finnair.com"),
            (["sas", "scandinavian"], "flysas.com"),
            (["tap"], "flytap.com"),
            (["aegean"], "aegeanair.com"),
            (["etihad"], "etihad.com"),
            (["saudia", "saudi arabian"], "saudia.com"),
            (["gulf air"], "gulfair.com"),
            (["flydubai"], "flydubai.com"),
            (["air arabia"], "airarabia.com"),
            (["united"], "united.com"),
            (["delta"], "delta.com"),
            (["american airlines", "american"], "aa.com"),
            (["air canada"], "aircanada.com"),
            (["jetblue"], "jetblue.com"),
            (["singapore airlines", "singapore"], "singaporeair.com"),
            (["cathay"], "cathaypacific.com"),
            (["ana", "all nippon"], "ana.co.jp"),
            (["jal", "japan airlines"], "jal.co.jp"),
        ]

        for mapping in mappings where mapping.keywords.contains(where: { lower.contains($0) }) {
            return mapping.domain
        }

        let stripped = lower
            .replacingOccurrences(of: " airlines", with: "")
            .replacingOccurrences(of: " airways", with: "")
            .replacingOccurrences(of: " air", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !stripped.isEmpty else { return nil }
        return "\(stripped).com"
    }

    static func clearbitURL(for airlineName: String, size: CGFloat) -> URL? {
        guard let domain = domain(for: airlineName) else { return nil }
        let host = domain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? domain
        return URL(string: "https://logo.clearbit.com/\(host)?size=\(Int(size * 3))")
    }

    static func faviconURL(for airlineName: String) -> URL? {
        guard let domain = domain(for: airlineName) else { return nil }
        let host = domain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? domain
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }
}

struct AirlineLogo: View {
    let airlineName: String
    let size: CGFloat
    let loadsRemoteImage: Bool
    @State private var canLoadRemoteLogo = false

    init(airlineName: String, size: CGFloat = 24, loadsRemoteImage: Bool = false) {
        self.airlineName = airlineName
        self.size = size
        self.loadsRemoteImage = loadsRemoteImage
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                )

            if loadsRemoteImage, canLoadRemoteLogo, let clearbitURL = AirlineBrandResolver.clearbitURL(for: airlineName, size: size) {
                AsyncImage(url: clearbitURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.14)
                    case .failure:
                        faviconFallback
                    default:
                        placeholderContent
                    }
                }
            } else {
                placeholderContent
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .onAppear {
            guard loadsRemoteImage else { return }
            canLoadRemoteLogo = true
        }
    }

    @ViewBuilder
    private var faviconFallback: some View {
        if let faviconURL = AirlineBrandResolver.faviconURL(for: airlineName) {
            AsyncImage(url: faviconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.16)
                default:
                    placeholderContent
                }
            }
        } else {
            placeholderContent
        }
    }

    private var placeholderContent: some View {
        Text(String(airlineName.first ?? "A"))
            .font(.system(size: size * 0.42, weight: .black, design: .default))
            .foregroundStyle(Theme.amber)
    }
}
