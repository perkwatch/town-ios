import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Sunset palette

extension Color {
    init(townHex hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

enum TownSunset {
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(townHex: "#500090"),
                Color(townHex: "#E8505F"),
                Color(townHex: "#F07848"),
                Color(townHex: "#FCA14D")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Warm fade colour used for the fresh-count accents.
    static var fade: Color {
        Color(townHex: "#FCA14D")
    }
}

// MARK: - Shared bits

private struct TownMark: View {
    var size: CGFloat = 40

    var body: some View {
        Image("TownT")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

private struct FreshBadge: View {
    var count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(TownSunset.fade.opacity(0.9))
            )
    }
}

// MARK: - Live Activity

struct TownPresenceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TownPresenceAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 12) {
                TownMark(size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Town")
                        .font(.headline.bold())
                        .foregroundStyle(TownSunset.gradient)
                    Text(context.state.headline)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(context.state.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                if context.state.freshCount > 0 {
                    FreshBadge(count: context.state.freshCount)
                }
            }
            .padding(14)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TownMark(size: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.freshCount > 0 {
                        FreshBadge(count: context.state.freshCount)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.headline)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                TownMark(size: 22)
            } compactTrailing: {
                if context.state.freshCount > 0 {
                    Text("\(context.state.freshCount)")
                        .font(.caption.bold())
                        .foregroundColor(TownSunset.fade)
                } else {
                    Circle()
                        .fill(TownSunset.fade)
                        .frame(width: 7, height: 7)
                }
            } minimal: {
                TownMark(size: 22)
            }
        }
    }
}
