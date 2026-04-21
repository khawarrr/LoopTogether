//
//  StepCountManager.swift
//  nameRunner
//

import Foundation
internal import HealthKit

@Observable
final class StepCountManager {
    var stepsToday: Int = 0
    var isLoading = false
    var hasRequestedAuth = false

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    static var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthAndLoad() async {
        guard Self.isHealthAvailable else { return }
        // HealthKit read auth status is intentionally opaque — don't check it.
        // Just request and query; the framework handles denial silently.
        try? await store.requestAuthorization(toShare: [], read: [stepType])
        hasRequestedAuth = true
        await loadStepsToday()
    }

    func loadStepsToday() async {
        guard Self.isHealthAvailable else { return }

        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

        let result = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int, Error>) in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(count))
            }
            store.execute(query)
        }

        stepsToday = result ?? 0
    }
}
