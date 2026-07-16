import SwiftUI
import WidflyKit

struct WidflyFormSection<Content: View, Trailing: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.mutedText)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 0.7)
                    )
            )

            if let footer {
                Text(footer)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mutedText)
                    .padding(.horizontal, 4)
            }
        }
    }
}

extension WidflyFormSection where Trailing == EmptyView {
    init(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(title, footer: footer, trailing: { EmptyView() }, content: content)
    }
}

struct WidflyFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.cardStroke.opacity(0.7))
            .frame(height: 0.6)
    }
}

struct WidflyDurationFilter: View {
    @Binding var isEnabled: Bool
    @Binding var maxHours: Double

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Limit Flight Duration", isOn: $isEnabled)
                .tint(Theme.amber)
                .padding(.vertical, 13)

            if isEnabled {
                WidflyFormDivider()
                Stepper(value: $maxHours, in: 2...30, step: 0.5) {
                    HStack {
                        Text("Max Duration")
                        Spacer()
                        Text(durationLabel)
                            .foregroundStyle(Theme.amber)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, 13)
            }
        }
        .foregroundStyle(.white)
    }

    private var durationLabel: String {
        let total = Int(maxHours * 60)
        let hours = total / 60
        let minutes = total % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}

struct WidflyTimeFilters: View {
    @Binding var departure: TimeFilter?
    @Binding var arrival: TimeFilter?

    var body: some View {
        VStack(spacing: 0) {
            timePicker("Departure Time", selection: $departure)
                .padding(.vertical, 5)
            WidflyFormDivider()
            timePicker("Arrival Time", selection: $arrival)
                .padding(.vertical, 5)
        }
        .foregroundStyle(.white)
    }

    private func timePicker(
        _ title: String,
        selection: Binding<TimeFilter?>
    ) -> some View {
        Picker(title, selection: selection) {
            Text("Any Time").tag(TimeFilter?.none)
            ForEach(TimeFilter.allCases) { filter in
                Text(filter.rawValue).tag(TimeFilter?.some(filter))
            }
        }
        .tint(Theme.amber)
    }
}

struct AirportField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    private var suggestions: [Airport] {
        AirportLookup.suggestions(for: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.mutedText)

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Theme.amber)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .foregroundStyle(.white)
                    .tint(Theme.amber)
            }

            if isFocused,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, airport in
                        if index > 0 {
                            WidflyFormDivider()
                        }
                        Button {
                            text = airport.code
                            isFocused = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airport.displayTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(airport.displaySubtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.mutedText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.amber)
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.background.opacity(0.88))
                )
            }
        }
        .padding(.vertical, 13)
        .accessibilityLabel(title)
    }
}
