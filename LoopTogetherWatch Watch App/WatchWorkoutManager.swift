//
//  WatchWorkoutManager.swift
//  LoopTogetherWatch Watch App
//

import Foundation
import HealthKit
import CoreLocation

@Observable
final class WatchWorkoutManager: NSObject {
    var isActive = false
    var isPaused = false
    var elapsedSeconds: Int = 0
    var distanceMeters: Double = 0
    var heartRate: Double = 0
    var calories: Double = 0
    var breadcrumbs: [[String: Double]] = []

    // Route navigation
    var currentRoute: WatchRoute?
    var currentStepIndex: Int = 0
    var hasArrivedAtDestination = false

    var currentInstruction: String {
        guard let route = currentRoute, currentStepIndex < route.steps.count else { return "" }
        return route.steps[currentStepIndex].instruction
    }
    var isRouteRun: Bool { currentRoute != nil }

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var locationManager: CLLocationManager?
    private var sessionStartDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStart: Date?
    private var timerTask: Task<Void, Never>?

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestPermissions() async {
        guard Self.isAvailable else { return }
        let types: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ]
        try? await healthStore.requestAuthorization(toShare: types, read: [])
    }

    func startRun(route: WatchRoute? = nil) {
        currentRoute = route
        currentStepIndex = 0
        hasArrivedAtDestination = false
        guard Self.isAvailable else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        guard let session = try? HKWorkoutSession(healthStore: healthStore, configuration: config) else { return }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        session.delegate = self
        builder.delegate = self
        workoutSession = session
        workoutBuilder = builder

        let now = Date()
        sessionStartDate = now
        session.startActivity(with: now)
        builder.beginCollection(withStart: now) { _, _ in }

        isActive = true
        isPaused = false
        elapsedSeconds = 0
        distanceMeters = 0
        heartRate = 0
        calories = 0
        breadcrumbs = []
        pausedDuration = 0

        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.requestWhenInUseAuthorization()
        lm.startUpdatingLocation()
        locationManager = lm

        startTimer()
    }

    func pauseRun() {
        workoutSession?.pause()
        locationManager?.stopUpdatingLocation()
        pauseStart = Date()
        isPaused = true
        timerTask?.cancel()
    }

    func resumeRun() {
        workoutSession?.resume()
        locationManager?.startUpdatingLocation()
        if let ps = pauseStart { pausedDuration += Date().timeIntervalSince(ps) }
        pauseStart = nil
        isPaused = false
        startTimer()
    }

    func endRun() async -> WatchRunData? {
        guard let session = workoutSession,
              let builder = workoutBuilder,
              let startDate = sessionStartDate else { return nil }

        let endDate = Date()
        session.end()
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        timerTask?.cancel()

        await withCheckedContinuation { cont in
            builder.endCollection(withEnd: endDate) { _, _ in cont.resume() }
        }
        await withCheckedContinuation { cont in
            builder.finishWorkout { _, _ in cont.resume() }
        }

        let duration = endDate.timeIntervalSince(startDate) - pausedDuration
        let effectiveCalories = calories > 0 ? calories : (distanceMeters / 1609.34) * 62

        let data = WatchRunData(
            startDate: startDate,
            durationSeconds: duration,
            distanceMeters: distanceMeters,
            caloriesBurned: effectiveCalories,
            heartRate: heartRate,
            pathCoordinates: breadcrumbs
        )

        isActive = false
        isPaused = false
        workoutSession = nil
        workoutBuilder = nil
        sessionStartDate = nil

        return data
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                DispatchQueue.main.async { [weak self] in
                    guard let self, let start = self.sessionStartDate, !self.isPaused else { return }
                    self.elapsedSeconds = Int(Date().timeIntervalSince(start) - self.pausedDuration)
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ session: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for type in collectedTypes {
                guard let qt = type as? HKQuantityType else { continue }
                let stats = workoutBuilder.statistics(for: qt)
                switch qt {
                case HKQuantityType(.heartRate):
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = stats?.mostRecentQuantity()?.doubleValue(for: unit) ?? self.heartRate
                case HKQuantityType(.distanceWalkingRunning):
                    self.distanceMeters = stats?.sumQuantity()?.doubleValue(for: .meter()) ?? self.distanceMeters
                case HKQuantityType(.activeEnergyBurned):
                    self.calories = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.calories
                default: break
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchWorkoutManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for loc in locations where loc.horizontalAccuracy > 0 && loc.horizontalAccuracy < 25 {
                self.breadcrumbs.append(["lat": loc.coordinate.latitude, "lng": loc.coordinate.longitude])
                self.advanceStepIfNeeded(userLocation: loc)
            }
        }
    }

    private func advanceStepIfNeeded(userLocation: CLLocation) {
        guard let route = currentRoute,
              currentStepIndex < route.steps.count - 1 else {
            // Check arrival at final destination
            if let route = currentRoute, !hasArrivedAtDestination {
                let dest = CLLocation(latitude: route.destination.latitude,
                                      longitude: route.destination.longitude)
                if userLocation.distance(from: dest) < 50 {
                    hasArrivedAtDestination = true
                }
            }
            return
        }
        let step = route.steps[currentStepIndex]
        let stepEnd = CLLocation(latitude: step.endCoordinate.latitude,
                                  longitude: step.endCoordinate.longitude)
        if userLocation.distance(from: stepEnd) < 40 {
            currentStepIndex += 1
        }
    }
}
