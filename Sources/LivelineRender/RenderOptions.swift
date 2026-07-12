#if os(macOS)
import Foundation
import Liveline
import SwiftUI

enum RenderCommandError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}

enum RenderChart: String, CaseIterable {
    case line
    case bars
    case candle
    case multi
    case stackedBar = "stacked-bar"
    case stackedArea = "stacked-area"
    case timeline
    case heatmap
    case radar
    case donut
    case gauge
    case funnel
}

enum RenderValueMotion: String, CaseIterable {
    case `static`
    case pulse
    case stream
}

struct RenderOptions {
    var chart: RenderChart = .line
    var values: [Double] = [98, 101, 100, 104, 108, 106, 111, 109, 113, 110, 116, 114]
    var labels: [String] = []
    var styleName = "dither"
    var ditherVariant = "gradient"
    var bloom = "aura"
    var cellSize = 2.0
    var intensity = 1.0
    var sparkleDensity = 0.035
    var animationSpeed = 1.2
    var ditherFPS = 30.0
    var animatedDither = true
    var valueMotion: RenderValueMotion = .static
    var width = 1920
    var height = 1080
    var fps = 30
    var duration = 4.0
    var theme = "dark"
    var accentHex = "3B82F6"
    var backgroundHex: String?
    var minimum = 0.0
    var maximum = 100.0
    var output = "liveline-chart.mp4"
    var showValue = false
    var grid = true
    var fill = true
    var randomSeed: UInt32 = 12_345

    static let help = """
    Render a Liveline chart directly to MP4 (macOS 13+).

    USAGE
      swift run liveline-render [options]

    CHART
      --chart <name>              \(RenderChart.allCases.map(\.rawValue).joined(separator: ", "))
      --values <csv>              Numeric samples or category values
      --labels <csv>              Optional category/series labels
      --value-motion <mode>       static, pulse, or stream (default: static)
      --min <number>              Gauge/radar lower bound (default: 0)
      --max <number>              Gauge/radar upper bound (default: 100)

    STYLE
      --style <standard|dither>   Chart-wide renderer style (default: dither)
      --variant <name>            gradient, dotted, hatched, or solid
      --bloom <name>              off, low, high, or aura
      --cell-size <number>        Dither cell size (default: 2)
      --intensity <number>        Dither intensity, 0...1 (default: 1)
      --sparkle-density <number>  Sparkle density, 0...0.2 (default: 0.035)
      --animation-speed <number>  Dither animation speed (default: 1.2)
      --dither-fps <number>       Dither frame cap (default: 30)
      --no-dither-animation       Render a stable dither texture
      --theme <dark|light>        Chart theme (default: dark)
      --accent <hex>              Accent colour, e.g. FF7A18
      --background <hex>          Canvas colour; inferred from theme by default
      --show-value                Show current value above the chart
      --no-grid                   Hide the cartesian grid
      --no-fill                   Hide line/area fill
      --seed <integer>            Deterministic effects seed

    VIDEO
      --width <pixels>            Even output width (default: 1920)
      --height <pixels>           Even output height (default: 1080)
      --fps <integer>             Output frame rate (default: 30)
      --duration <seconds>        Output duration (default: 4)
      --output <path>             MP4 destination (default: liveline-chart.mp4)

    OTHER
      --list-charts               Print supported chart names
      -h, --help                  Print this help

    EXAMPLES
      swift run liveline-render --chart line --variant dotted --values 92,98,95,108,112 --output line.mp4
      swift run liveline-render --chart donut --variant hatched --values 42,28,18,12 --labels Pro,Team,Starter,Other --output donut.mp4
      swift run liveline-render --chart gauge --values 72 --value-motion pulse --accent 22C55E --output gauge.mp4
    """

    static func parse(_ arguments: [String]) throws -> RenderOptions {
        var options = RenderOptions()
        var index = 0

        func value(after flag: String) throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw RenderCommandError.message("Missing value after \(flag)")
            }
            index = valueIndex
            return arguments[valueIndex]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                print(help)
                Foundation.exit(EXIT_SUCCESS)
            case "--list-charts":
                print(RenderChart.allCases.map(\.rawValue).joined(separator: "\n"))
                Foundation.exit(EXIT_SUCCESS)
            case "--chart":
                let raw = try value(after: argument)
                guard let chart = RenderChart(rawValue: raw) else {
                    throw RenderCommandError.message("Unknown chart '\(raw)'. Use --list-charts.")
                }
                options.chart = chart
            case "--values": options.values = try parseDoubles(try value(after: argument), flag: argument)
            case "--labels": options.labels = splitCSV(try value(after: argument))
            case "--value-motion":
                let raw = try value(after: argument)
                guard let motion = RenderValueMotion(rawValue: raw) else {
                    throw RenderCommandError.message("Unknown value motion '\(raw)'. Expected static, pulse, or stream.")
                }
                options.valueMotion = motion
            case "--style": options.styleName = try value(after: argument)
            case "--variant": options.ditherVariant = try value(after: argument)
            case "--bloom": options.bloom = try value(after: argument)
            case "--cell-size": options.cellSize = try parseDouble(try value(after: argument), flag: argument)
            case "--intensity": options.intensity = try parseDouble(try value(after: argument), flag: argument)
            case "--sparkle-density": options.sparkleDensity = try parseDouble(try value(after: argument), flag: argument)
            case "--animation-speed": options.animationSpeed = try parseDouble(try value(after: argument), flag: argument)
            case "--dither-fps": options.ditherFPS = try parseDouble(try value(after: argument), flag: argument)
            case "--no-dither-animation": options.animatedDither = false
            case "--width": options.width = try parseInt(try value(after: argument), flag: argument)
            case "--height": options.height = try parseInt(try value(after: argument), flag: argument)
            case "--fps": options.fps = try parseInt(try value(after: argument), flag: argument)
            case "--duration": options.duration = try parseDouble(try value(after: argument), flag: argument)
            case "--theme": options.theme = try value(after: argument)
            case "--accent": options.accentHex = try value(after: argument)
            case "--background": options.backgroundHex = try value(after: argument)
            case "--min": options.minimum = try parseDouble(try value(after: argument), flag: argument)
            case "--max": options.maximum = try parseDouble(try value(after: argument), flag: argument)
            case "--output": options.output = try value(after: argument)
            case "--show-value": options.showValue = true
            case "--no-grid": options.grid = false
            case "--no-fill": options.fill = false
            case "--seed":
                let raw = try value(after: argument)
                guard let seed = UInt32(raw) else { throw RenderCommandError.message("Invalid integer for --seed: '\(raw)'") }
                options.randomSeed = seed
            default:
                throw RenderCommandError.message("Unknown option '\(argument)'. Run with --help.")
            }
            index += 1
        }

        try options.validate()
        return options
    }

    func validate() throws {
        guard !values.isEmpty else { throw RenderCommandError.message("--values must contain at least one number") }
        guard values.count <= 10_000 else { throw RenderCommandError.message("--values supports at most 10,000 samples") }
        guard width >= 2, height >= 2, width <= 8_192, height <= 8_192,
              width.isMultiple(of: 2), height.isMultiple(of: 2),
              width * height <= 33_554_432
        else {
            throw RenderCommandError.message("--width and --height must be even, at most 8192, and no more than 32 megapixels combined")
        }
        guard (1...120).contains(fps) else { throw RenderCommandError.message("--fps must be between 1 and 120") }
        guard duration.isFinite, duration > 0, duration <= 600 else {
            throw RenderCommandError.message("--duration must be greater than 0 and at most 600 seconds")
        }
        guard minimum.isFinite, maximum.isFinite, minimum < maximum else {
            throw RenderCommandError.message("--min must be less than --max")
        }
        guard ["standard", "dither"].contains(styleName) else {
            throw RenderCommandError.message("--style must be standard or dither")
        }
        guard ["dark", "light"].contains(theme) else { throw RenderCommandError.message("--theme must be dark or light") }
        guard ["gradient", "dotted", "hatched", "solid"].contains(ditherVariant) else {
            throw RenderCommandError.message("Unknown dither variant '\(ditherVariant)'")
        }
        guard ["off", "low", "high", "aura"].contains(bloom) else {
            throw RenderCommandError.message("Unknown bloom '\(bloom)'")
        }
        _ = try Color(hex: accentHex)
        if let backgroundHex { _ = try Color(hex: backgroundHex) }
        guard outputURL.pathExtension.lowercased() == "mp4" else {
            throw RenderCommandError.message("--output must use the .mp4 extension")
        }
    }

    var outputURL: URL {
        URL(fileURLWithPath: output, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL
    }

    var chartStyle: LivelineChartStyle {
        guard styleName == "dither" else { return .standard }
        let variant: LivelineDitherVariant = switch ditherVariant {
        case "dotted": .dotted
        case "hatched": .hatched
        case "solid": .solid
        default: .gradient
        }
        let resolvedBloom: LivelineDitherBloom = switch bloom {
        case "off": .off
        case "high": .high
        case "aura": .aura
        default: .low
        }
        return .dither(LivelineDitherStyle(
            variant: variant,
            bloom: resolvedBloom,
            cellSize: cellSize,
            intensity: intensity,
            sparkleDensity: sparkleDensity,
            animationSpeed: animationSpeed,
            maximumFramesPerSecond: ditherFPS,
            animated: animatedDither
        ))
    }

    var themeMode: LivelineThemeMode { theme == "light" ? .light : .dark }
    var accent: Color { try! Color(hex: accentHex) }
    var background: Color {
        if let backgroundHex { return try! Color(hex: backgroundHex) }
        return theme == "light" ? .white : Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    }

    private static func splitCSV(_ string: String) -> [String] {
        string.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func parseDoubles(_ string: String, flag: String) throws -> [Double] {
        try splitCSV(string).map { try parseDouble($0, flag: flag) }
    }

    private static func parseDouble(_ string: String, flag: String) throws -> Double {
        guard let value = Double(string), value.isFinite else {
            throw RenderCommandError.message("Invalid number for \(flag): '\(string)'")
        }
        return value
    }

    private static func parseInt(_ string: String, flag: String) throws -> Int {
        guard let value = Int(string) else {
            throw RenderCommandError.message("Invalid integer for \(flag): '\(string)'")
        }
        return value
    }
}

extension Color {
    init(hex: String) throws {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let integer = UInt64(value, radix: 16) else {
            throw RenderCommandError.message("Invalid hex colour '\(hex)'; expected RRGGBB")
        }
        self.init(
            red: Double((integer >> 16) & 0xff) / 255,
            green: Double((integer >> 8) & 0xff) / 255,
            blue: Double(integer & 0xff) / 255
        )
    }
}
#endif
