import Foundation

extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var median: Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = count / 2
        return count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = mean
        let variance = map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(count - 1)
        return sqrt(variance)
    }

    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = p / 100.0 * Double(count - 1)
        let lower = Int(index)
        let upper = Swift.min(lower + 1, count - 1)
        let frac = index - Double(lower)
        return sorted[lower] + frac * (sorted[upper] - sorted[lower])
    }

    func movingAverage(window: Int) -> [Double] {
        guard window > 0, !isEmpty else { return self }
        return indices.map { i in
            let start = Swift.max(0, i - window + 1)
            let slice = self[start...i]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    func weightedAverage(weights: [Double]) -> Double {
        guard count == weights.count, !isEmpty else { return mean }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return 0 }
        return zip(self, weights).map(*).reduce(0, +) / totalWeight
    }
}
