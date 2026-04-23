//
//  WatchWorkoutManager.swift
//  LoopTogetherWatch Watch App
//

import Foundation
import HealthKit
import CoreLocation
import CoreMotion

enum WorkoutMode {
    case freeRun, outdoorWalk, indoorWalk

    var activityType: HKWorkoutActivityType { self == .freeRun ? .running : .walking }
    var locationType: HKWorkoutSessionLocationType { self == .indoorWalk ? .indoor : .outdoor }
    var usesGPS: Bool { self != .indoorWalk }
    var displayName: String {
        switch self {
        case .freeRun:     return "Free Run"
        case .outdoorWalk: return "Outdoor Walk"
        case .indoorWalk:  return "Indoor Walk"
        }
    }
}

@Observable
final class WatchWorkoutManager: NSObject {
    var isActive = false
    var currentMode: WorkoutMode = .freeRun
    var lastRun: WatchRunData?
    var currentCoordinate: CLLocationCoordinate2D?
    var currentHeading: CLLocationDirection = 0
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
    private var lastLocation: CLLocation?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var pedometer: CMPedometer?

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestPermissions() async {
        guard Self.isAvailable else { return }
        let types: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ]
        try? await healthStore.requestAuthorization(toShare: types, read: types)
    }

    func startRun(mode: WorkoutMode = .freeRun, route: WatchRoute? = nil) {
        currentMode = mode
        currentRoute = route
        currentStepIndex = 0
        hasArrivedAtDestination = false
        guard Self.isAvailable else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = mode.activityType
        config.locationType = mode.locationType

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
        // beginCollection is called in the delegate once session reaches .running

        isActive = true
        isPaused = false
        elapsedSeconds = 0
        distanceMeters = 0
        heartRate = 0
        calories = 0
        breadcrumbs = []
        pausedDuration = 0
        lastLocation = nil

        if mode.usesGPS {
            let lm = CLLocationManager()
            lm.delegate = self
            lm.desiredAccuracy = kCLLocationAccuracyBest
            lm.requestWhenInUseAuthorization()
            lm.startUpdatingLocation()
            lm.startUpdatingHeading()
            locationManager = lm
        }

        startTimer()
        startHeartRateObserver()
        if mode == .indoorWalk { startPedometer(from: now) }
    }

    private func startHeartRateObserver() {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil)
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHeartRateSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHeartRateSamples(samples)
        }
        healthStore.execute(query)
        heartRateQuery = query
    }

    private func startPedometer(from date: Date) {
        guard CMPedometer.isDistanceAvailable() else { return }
        let base = distanceMeters
        let p = CMPedometer()
        p.startUpdates(from: date) { [weak self] data, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async {
                self.distanceMeters = base + (data.distance?.doubleValue ?? 0)
            }
        }
        pedometer = p
    }

    private func handleHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let last = samples.last else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = last.quantity.doubleValue(for: unit)
        DispatchQueue.main.async { self.heartRate = bpm }
    }

    func pauseRun() {
        workoutSession?.pause()
        locationManager?.stopUpdatingLocation()
        pedometer?.stopUpdates()
        pauseStart = Date()
        lastLocation = nil
        isPaused = true
        timerTask?.cancel()
    }

    func resumeRun() {
        workoutSession?.resume()
        lastLocation = nil
        locationManager?.startUpdatingLocation()
        if let ps = pauseStart { pausedDuration += Date().timeIntervalSince(ps) }
        pauseStart = nil
        isPaused = false
        startTimer()
        if currentMode == .indoorWalk { startPedometer(from: Date()) }
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
        if let q = heartRateQuery { healthStore.stop(q) }
        heartRateQuery = nil
        pedometer?.stopUpdates()
        pedometer = nil

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
            pathCoordinates: breadcrumbs,
            workoutType: currentMode.displayName
        )

        lastRun = data
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
                        from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .running {
            workoutBuilder?.beginCollection(withStart: date) { _, _ in }
        }
    }
    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        print("[Workout] Session failed: \(error)")
    }
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
            guard let self, !self.isPaused else { return }
            for loc in locations where loc.horizontalAccuracy > 0 && loc.horizontalAccuracy < 20 {
                self.currentCoordinate = loc.coordinate
                if let prev = self.lastLocation {
                    let delta = loc.distance(from: prev)
                    if delta >= 3 {
                        self.distanceMeters += delta
                        self.lastLocation = loc
                        self.breadcrumbs.append(["lat": loc.coordinate.latitude, "lng": loc.coordinate.longitude])
                    }
                } else {
                    self.lastLocation = loc
                }
                self.advanceStepIfNeeded(userLocation: loc)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        DispatchQueue.main.async { self.currentHeading = newHeading.trueHeading }
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
