//
//  RunActivityAttributes.swift
//  nameRunner + LoopTogetherWidget
//
//  Add this file to BOTH the nameRunner and LoopTogetherWidget targets.
//

import ActivityKit
import Foundation

struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceMiles: Double
        var paceMinPerMile: Double   // 0 when unavailable
        var isPaused: Bool
    }

    let runType: String   // "Free Run" or "Route Run"
    let startDate: Date
}
