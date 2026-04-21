//
//  WatchRunData.swift
//  nameRunner + LoopTogetherWatch
//
//  Add this file to BOTH the nameRunner and LoopTogetherWatch targets in Xcode.
//

import Foundation

struct WatchRunData {
    let startDate: Date
    let durationSeconds: TimeInterval
    let distanceMeters: Double
    let caloriesBurned: Double
    let heartRate: Double
    let pathCoordinates: [[String: Double]]   // [{lat, lng}]

    func toDictionary() -> [String: Any] {
        [
            "type": "completedRun",
            "startDate": startDate.timeIntervalSince1970,
            "durationSeconds": durationSeconds,
            "distanceMeters": distanceMeters,
            "caloriesBurned": caloriesBurned,
            "heartRate": heartRate,
            "pathCoordinates": pathCoordinates
        ]
    }

    static func from(_ dict: [String: Any]) -> WatchRunData? {
        guard
            let ts       = dict["startDate"]       as? TimeInterval,
            let duration = dict["durationSeconds"] as? TimeInterval,
            let distance = dict["distanceMeters"]  as? Double
        else { return nil }
        return WatchRunData(
            startDate:        Date(timeIntervalSince1970: ts),
            durationSeconds:  duration,
            distanceMeters:   distance,
            caloriesBurned:   dict["caloriesBurned"]   as? Double             ?? 0,
            heartRate:        dict["heartRate"]         as? Double             ?? 0,
            pathCoordinates:  dict["pathCoordinates"]   as? [[String: Double]] ?? []
        )
    }
}
