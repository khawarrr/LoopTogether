//
//  RunActivityManager.swift
//  nameRunner
//

import ActivityKit
import Foundation

@Observable
final class RunActivityManager {
    private var activity: Activity<RunActivityAttributes>?

    func start(runType: String, startDate: Date) {
        let info = ActivityAuthorizationInfo()
        print("[LiveActivity] areActivitiesEnabled: \(info.areActivitiesEnabled)")
        guard info.areActivitiesEnabled else {
            print("[LiveActivity] Blocked — activities not enabled")
            return
        }
        let attributes = RunActivityAttributes(runType: runType, startDate: startDate)
        let state = RunActivityAttributes.ContentState(
            distanceMiles: 0, paceMinPerMile: 0, isPaused: false
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("[LiveActivity] Started successfully, id: \(activity?.id ?? "nil")")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func update(distanceMiles: Double, paceMinPerMile: Double, isPaused: Bool) {
        let state = RunActivityAttributes.ContentState(
            distanceMiles: distanceMiles,
            paceMinPerMile: paceMinPerMile,
            isPaused: isPaused
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        Task {
            await activity?.end(.init(state: activity?.content.state ?? .init(
                distanceMiles: 0, paceMinPerMile: 0, isPaused: false
            ), staleDate: nil), dismissalPolicy: .immediate)
        }
        activity = nil
    }
}
