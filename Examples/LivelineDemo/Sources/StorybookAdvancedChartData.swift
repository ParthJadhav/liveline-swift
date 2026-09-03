import Foundation
import Liveline

extension StorybookData {
    static var distributions: [LivelineDistributionSeries] {
        let mobile = (0..<96).map { index -> Double in
            68 + sin(Double(index) * 0.31) * 12 + cos(Double(index) * 0.11) * 5
        }
        let web = (0..<104).map { index -> Double in
            82 + sin(Double(index) * 0.27 + 1.2) * 16 + cos(Double(index) * 0.08) * 7
        }
        let api = (0..<88).map { index -> Double in
            54 + sin(Double(index) * 0.36 + 2.1) * 9 + pow(sin(Double(index) * 0.09), 4) * 18
        }
        return [
            LivelineDistributionSeries(id: "mobile", label: "Mobile", values: mobile),
            LivelineDistributionSeries(id: "web", label: "Web", values: web),
            LivelineDistributionSeries(id: "api", label: "API", values: api),
        ]
    }

    static var calendarActivity: [LivelineCalendarValue] {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: baseTime - 97 * 86_400)
        return (0..<98).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: start) else { return nil }
            let value = max(
                0, sin(Double(index) * 0.41) * 8 + cos(Double(index) * 0.13) * 5 + Double(index % 9))
            return LivelineCalendarValue(date: date, value: index % 17 == 0 ? 0 : value)
        }
    }

    static var ganttTasks: [LivelineGanttTask] {
        [
            LivelineGanttTask(
                id: "research", label: "Research", start: baseTime - 170, end: baseTime - 105, lane: 0,
                progress: 1),
            LivelineGanttTask(
                id: "design", label: "Design", start: baseTime - 135, end: baseTime - 55, lane: 1,
                progress: 0.82, dependencyIDs: ["research"]),
            LivelineGanttTask(
                id: "ios", label: "iOS", start: baseTime - 92, end: baseTime - 8, lane: 2, progress: 0.64,
                dependencyIDs: ["design"]),
            LivelineGanttTask(
                id: "qa", label: "QA", start: baseTime - 42, end: baseTime + 18, lane: 3, progress: 0.28,
                dependencyIDs: ["ios"]),
            LivelineGanttTask(
                id: "launch", label: "Launch", start: baseTime + 8, end: baseTime + 28, lane: 1,
                progress: 0, dependencyIDs: ["qa"]),
        ]
    }

    static var chordLinks: [LivelineChordLink] {
        [
            LivelineChordLink(source: "Product", target: "Engineering", value: 32),
            LivelineChordLink(source: "Engineering", target: "Support", value: 18),
            LivelineChordLink(source: "Support", target: "Product", value: 14),
            LivelineChordLink(source: "Design", target: "Engineering", value: 22),
            LivelineChordLink(source: "Product", target: "Design", value: 26),
            LivelineChordLink(source: "Support", target: "Design", value: 9),
        ]
    }

    static var parallelRecords: [LivelineParallelRecord] {
        [
            LivelineParallelRecord(id: "alpha", label: "Alpha", values: [82, 44, 91, 68, 73]),
            LivelineParallelRecord(id: "beta", label: "Beta", values: [64, 88, 57, 79, 62]),
            LivelineParallelRecord(id: "gamma", label: "Gamma", values: [91, 61, 76, 48, 87]),
            LivelineParallelRecord(id: "delta", label: "Delta", values: [52, 73, 69, 92, 58]),
        ]
    }

    static var hexbinPoints: [LivelineXYPoint] {
        (0..<260).map { index in
            let cluster = index % 3
            let angle = Double(index) * 2.399_963
            let radius = sqrt(Double(index % 87)) * 0.82
            let centerX = [28.0, 62, 76][cluster]
            let centerY = [68.0, 34, 72][cluster]
            return LivelineXYPoint(
                id: "hex-\(index)",
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius,
                weight: 1 + Double(index % 5) * 0.18
            )
        }
    }

    static var bumpSeries: [LivelineRankSeries] {
        let labels = ["Orion", "Nova", "Atlas", "Lumen", "Aster"]
        return labels.enumerated().map { seriesIndex, label in
            LivelineRankSeries(
                id: label.lowercased(),
                label: label,
                points: (0..<9).map { index in
                    let rank =
                        1
                        + ((seriesIndex * 2 + index * (seriesIndex + 1)
                            + Int(abs(sin(Double(index + seriesIndex)) * 4))) % labels.count)
                    return LivelineRankPoint(time: baseTime - Double(8 - index) * 20, rank: Double(rank))
                }
            )
        }
    }

    static var horizonPoints: [LivelinePoint] {
        (0..<96).map { index in
            let t = Double(index)
            return LivelinePoint(
                time: baseTime - Double(95 - index) * 2,
                value: sin(t * 0.18) * 26 + cos(t * 0.061) * 17 + sin(t * 0.47) * 7)
        }
    }

    static var marimekkoColumns: [LivelineMarimekkoColumn] {
        [
            LivelineMarimekkoColumn(
                id: "na", label: "NA", width: 46,
                segments: [
                    LivelineCategoryValue(id: "pro", label: "Pro", value: 62),
                    LivelineCategoryValue(id: "team", label: "Team", value: 28),
                    LivelineCategoryValue(id: "free", label: "Free", value: 10),
                ]),
            LivelineMarimekkoColumn(
                id: "eu", label: "EU", width: 32,
                segments: [
                    LivelineCategoryValue(id: "pro", label: "Pro", value: 45),
                    LivelineCategoryValue(id: "team", label: "Team", value: 38),
                    LivelineCategoryValue(id: "free", label: "Free", value: 17),
                ]),
            LivelineMarimekkoColumn(
                id: "apac", label: "APAC", width: 22,
                segments: [
                    LivelineCategoryValue(id: "pro", label: "Pro", value: 34),
                    LivelineCategoryValue(id: "team", label: "Team", value: 29),
                    LivelineCategoryValue(id: "free", label: "Free", value: 37),
                ]),
        ]
    }

    static var networkNodes: [LivelineNetworkNode] {
        [
            LivelineNetworkNode(id: "gateway", label: "Gateway", weight: 18, group: "edge"),
            LivelineNetworkNode(id: "auth", label: "Auth", weight: 11, group: "service"),
            LivelineNetworkNode(id: "api", label: "API", weight: 16, group: "service"),
            LivelineNetworkNode(id: "jobs", label: "Jobs", weight: 9, group: "service"),
            LivelineNetworkNode(id: "db", label: "Database", weight: 14, group: "data"),
            LivelineNetworkNode(id: "cache", label: "Cache", weight: 8, group: "data"),
        ]
    }

    static var networkEdges: [LivelineNetworkEdge] {
        [
            LivelineNetworkEdge(source: "gateway", target: "auth", value: 8),
            LivelineNetworkEdge(source: "gateway", target: "api", value: 18),
            LivelineNetworkEdge(source: "api", target: "db", value: 14),
            LivelineNetworkEdge(source: "api", target: "cache", value: 9),
            LivelineNetworkEdge(source: "api", target: "jobs", value: 7),
            LivelineNetworkEdge(source: "jobs", target: "db", value: 5),
        ]
    }

    static var contourSamples: [LivelineContourSample] {
        (0..<8).flatMap { y in
            (0..<11).map { x in
                let dx = Double(x) - 4.2
                let dy = Double(y) - 3.1
                let first = exp(-(dx * dx + dy * dy) / 8) * 92
                let second = exp(-(pow(Double(x) - 8.0, 2) + pow(Double(y) - 5.5, 2)) / 4) * 58
                return LivelineContourSample(
                    id: "\(x)-\(y)", x: Double(x), y: Double(y), value: first + second)
            }
        }
    }

    static var ternaryPoints: [LivelineTernaryPoint] {
        [
            LivelineTernaryPoint(id: "alpha", label: "Alpha", a: 62, b: 24, c: 14, magnitude: 18),
            LivelineTernaryPoint(id: "beta", label: "Beta", a: 28, b: 51, c: 21, magnitude: 12),
            LivelineTernaryPoint(id: "gamma", label: "Gamma", a: 18, b: 27, c: 55, magnitude: 15),
            LivelineTernaryPoint(id: "delta", label: "Delta", a: 36, b: 31, c: 33, magnitude: 9),
            LivelineTernaryPoint(id: "epsilon", label: "Epsilon", a: 47, b: 42, c: 11, magnitude: 7),
        ]
    }

    static var volumeProfile: [LivelinePriceVolume] {
        (0..<22).map { index in
            let price = 94 + Double(index) * 0.6
            let center = Double(index) - 11
            let volume = 18 + exp(-(center * center) / 38) * 92 + sin(Double(index) * 0.74) * 8
            return LivelinePriceVolume(price: price, volume: max(volume, 2))
        }
    }

    static var marketDepth: [LivelineOrderBookLevel] {
        (1...14).flatMap { index in
            [
                LivelineOrderBookLevel(price: 100 - Double(index) * 0.18, bidSize: 4 + Double(index) * 1.7),
                LivelineOrderBookLevel(
                    price: 100 + Double(index) * 0.18, askSize: 3 + Double(index) * 1.55),
            ]
        }
    }

    static var candleVolumes: [LivelineCandleVolume] {
        candles(width: 15).committed.map { candle in
            LivelineCandleVolume(
                time: candle.time,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: 34 + abs(candle.close - candle.open) * 28 + Double(Int(candle.time) % 9) * 3
            )
        }
    }
}
