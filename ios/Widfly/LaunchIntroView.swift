import SwiftUI

struct LaunchIntroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var isFlying = false
    @State private var isVisible = true
    @State private var logoVisible = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Widfly")
                    .font(.system(size: 46, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.94)

                GeometryReader { proxy in
                    ZStack {
                        Capsule()
                            .fill(Theme.cardStroke)
                            .frame(height: 2)
                            .scaleEffect(x: isFlying ? 1 : 0.05, anchor: .leading)
                            .padding(.horizontal, 34)

                        Circle()
                            .fill(Theme.amber)
                            .frame(width: 7, height: 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 31)

                        Circle()
                            .strokeBorder(Theme.amber, lineWidth: 2)
                            .frame(width: 9, height: 9)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 31)

                        Image(systemName: "airplane")
                            .font(.system(size: 31, weight: .bold))
                            .foregroundStyle(Theme.amber)
                            .shadow(color: Theme.amber.opacity(0.3), radius: 10)
                            .rotationEffect(.degrees(reduceMotion ? 0 : -4))
                            .offset(x: reduceMotion ? 0 : (isFlying ? proxy.size.width * 0.36 : -proxy.size.width * 0.36))
                            .scaleEffect(isFlying ? 1 : 0.82)
                            .opacity(isFlying ? 1 : 0.25)
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 24)

                Text("Track the journey. Catch the price.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mutedText)
                    .opacity(logoVisible ? 1 : 0)
            }
            .padding(.horizontal, 20)
        }
        .opacity(isVisible ? 1 : 0)
        .task {
            await runAnimation()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Widfly")
    }

    @MainActor
    private func runAnimation() async {
        withAnimation(.easeOut(duration: 0.35)) {
            logoVisible = true
        }

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.55)) {
                isFlying = true
            }
        } else {
            withAnimation(.easeInOut(duration: 1.25)) {
                isFlying = true
            }
        }

        try? await Task.sleep(for: .seconds(1.35))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.35)) {
            isVisible = false
        }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}
