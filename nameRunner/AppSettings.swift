//
//  AppSettings.swift
//  nameRunner
//

import Foundation

@Observable
final class AppSettings {
    var useMetric: Bool = UserDefaults.standard.bool(forKey: "useMetric") {
        didSet { UserDefaults.standard.set(useMetric, forKey: "useMetric") }
    }
    var voiceGuidanceEnabled: Bool = (UserDefaults.standard.object(forKey: "voiceGuidanceEnabled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(voiceGuidanceEnabled, forKey: "voiceGuidanceEnabled") }
    }
    var runnerAvatar: String = UserDefaults.standard.string(forKey: "runnerAvatar") ?? "male" {
        didSet { UserDefaults.standard.set(runnerAvatar, forKey: "runnerAvatar") }
    }

    var distanceUnit: String { useMetric ? "km" : "mi" }
    var paceUnit: String { useMetric ? "/km" : "/mi" }

    func formatDistance(_ meters: Double, decimals: Int = 2) -> String {
        let val = useMetric ? meters / 1000 : meters / 1609.34
        return String(format: "%.\(decimals)f \(distanceUnit)", val)
    }

    func formatMiles(_ miles: Double, decimals: Int = 1) -> String {
        let meters = miles * 1609.34
        return formatDistance(meters, decimals: decimals)
    }

    func formatPace(_ minutesPerMile: Double) -> String {
        let pace = useMetric ? minutesPerMile / 1.60934 : minutesPerMile
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d \(paceUnit)", m, s)
    }
}
