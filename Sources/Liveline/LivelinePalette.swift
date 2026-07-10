import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias LivelinePlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias LivelinePlatformColor = NSColor
#endif

struct LivelineRGBA: Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func withAlpha(_ alpha: Double) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func blended(to target: LivelineRGBA, t: Double) -> LivelineRGBA {
        let progress = min(max(t, 0), 1)
        return LivelineRGBA(
            red: red + (target.red - red) * progress,
            green: green + (target.green - green) * progress,
            blue: blue + (target.blue - blue) * progress,
            alpha: alpha + (target.alpha - alpha) * progress
        )
    }
}

struct LivelinePalette {
    var line: Color
    var lineRGB: LivelineRGBA
    var lineWidth: CGFloat
    var fillTop: Color
    var fillBottom: Color
    var gridLine: Color
    var gridLabel: Color
    var gridLabelRGB: LivelineRGBA
    var emptyText: Color
    var dotUp: Color
    var dotDown: Color
    var dotFlat: Color
    var glowUp: Color
    var glowDown: Color
    var glowFlat: Color
    var badgeOuterBackground: Color
    var badgeOuterShadow: Color
    var badgeBackground: Color
    var badgeText: Color
    var dashLine: Color
    var referenceLine: Color
    var referenceLabel: Color
    var timeLabel: Color
    var crosshairLine: Color
    var tooltipBackground: Color
    var tooltipText: Color
    var tooltipBorder: Color
    var backgroundRGB: LivelineRGBA
}

extension LivelinePalette {
    static func resolve(accent: Color, mode: LivelineThemeMode, lineWidth: CGFloat) -> LivelinePalette {
        let accentRGB = accent.livelineRGBA()
        let isDark = mode == .dark

        return LivelinePalette(
            line: accent,
            lineRGB: accentRGB,
            lineWidth: lineWidth,
            fillTop: accentRGB.withAlpha(isDark ? 0.12 : 0.08),
            fillBottom: accentRGB.withAlpha(0),
            gridLine: isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
            gridLabel: isDark ? Color.white.opacity(0.40) : Color.black.opacity(0.35),
            gridLabelRGB: isDark
                ? LivelineRGBA(red: 1, green: 1, blue: 1, alpha: 0.40)
                : LivelineRGBA(red: 0, green: 0, blue: 0, alpha: 0.35),
            emptyText: isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.55),
            dotUp: Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
            dotDown: Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
            dotFlat: accent,
            glowUp: Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255).opacity(0.18),
            glowDown: Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255).opacity(0.18),
            glowFlat: accentRGB.withAlpha(0.12),
            badgeOuterBackground: isDark ? Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255).opacity(0.95) : Color.white.opacity(0.95),
            badgeOuterShadow: isDark ? Color.black.opacity(0.40) : Color.black.opacity(0.15),
            badgeBackground: accent,
            badgeText: .white,
            dashLine: accentRGB.withAlpha(0.40),
            referenceLine: isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12),
            referenceLabel: isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40),
            timeLabel: isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.30),
            crosshairLine: isDark ? Color.white.opacity(0.20) : Color.black.opacity(0.12),
            tooltipBackground: isDark ? Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255).opacity(0.95) : Color.white.opacity(0.95),
            tooltipText: isDark ? Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255) : Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
            tooltipBorder: isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
            backgroundRGB: isDark ? LivelineRGBA(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1) : LivelineRGBA(red: 1, green: 1, blue: 1, alpha: 1)
        )
    }
}

extension Color {
    func livelineRGBA() -> LivelineRGBA {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        LivelinePlatformColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return LivelineRGBA(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        #elseif canImport(AppKit)
        let color = LivelinePlatformColor(self).usingColorSpace(.deviceRGB) ?? .systemBlue
        return LivelineRGBA(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
        #else
        return LivelineRGBA(red: 59 / 255, green: 130 / 255, blue: 246 / 255, alpha: 1)
        #endif
    }
}
