//
//  RunModels.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import Foundation
internal import MapKit
import CoreLocation
import FirebaseAuth

// MARK: - Active run session

/// Represents a run currently in progress.
/// Supports both route-based runs (with an MKRoute) and free runs.
/// Tracks pausable elapsed time and real GPS breadcrumbs for the path.
@Observable
final class RunSession: Identifiable {
    let id = UUID()

    /// The planned route. `nil` for free runs.
    let route: MKRoute?
    let destination: CLLocationCoordinate2D?
    let startedAt: Date

    /// Live progress along the planned route. Only non-nil for route-based runs.
    var progress: RouteProgress?

    /// Remaining legs for loop runs. Front is popped each time the current leg completes.
    private(set) var pendingLegs: [MKRoute]
    /// All pending leg polylines stored upfront for map display (before each leg is consumed).
    private let allPendingLegCoords: [[CLLocationCoordinate2D]]
    /// Index of the currently active leg (0 = outbound).
    private(set) var currentLegIndex = 0

    /// Actual GPS path of the run. Grows as location updates come in.
    private(set) var breadcrumbs: [CLLocationCoordinate2D] = []

    /// Distance (meters) computed from GPS breadcrumbs — the ground truth
    /// for how far the user has actually moved.
    private(set) var trackedDistanceMeters: Double = 0

    // Elapsed time is computed from (a) time accumulated before the current
    // active segment + (b) time since the current segment started.
    // `currentSegmentStart == nil` means paused.
    private var accumulatedBeforePause: TimeInterval = 0
    private var currentSegmentStart: Date?

    init(route: MKRoute?, destination: CLLocationCoordinate2D?, pendingLegs: [MKRoute] = []) {
        self.route = route
        self.destination = destination
        self.pendingLegs = pendingLegs
        self.allPendingLegCoords = pendingLegs.map { $0.polyline.coordinates }
        self.startedAt = Date()
        if let route {
            self.progress = RouteProgress(route: route)
        }
        self.currentSegmentStart = Date()
    }

    var isFreeRun: Bool { route == nil }

    // MARK: Time

    var isPaused: Bool {
        currentSegmentStart == nil
    }

    /// Live elapsed time. Computed on demand, so it stays correct even
    /// if the UI has been hidden.
    var elapsedTime: TimeInterval {
        if let segmentStart = currentSegmentStart {
            return accumulatedBeforePause + Date().timeIntervalSince(segmentStart)
        }
        return accumulatedBeforePause
    }

    func pause() {
        guard let segmentStart = currentSegmentStart else { return }
        accumulatedBeforePause += Date().timeIntervalSince(segmentStart)
        currentSegmentStart = nil
    }

    func resume() {
        guard currentSegmentStart == nil else { return }
        currentSegmentStart = Date()
    }

    // MARK: Location updates

    /// Called on every GPS update. Records breadcrumbs + distance if the
    /// reading passes accuracy/movement filters, and updates route progress
    /// if applicable.
    func updateProgress(userLocation: CLLocation) {
        guard !isPaused else { return }

        // Accuracy filter: skip noisy or invalid readings.
        guard userLocation.horizontalAccuracy > 0,
              userLocation.horizontalAccuracy < 20 else { return }

        // Skip stale readings — tighter window catches batched background updates.
        guard userLocation.timestamp.timeIntervalSinceNow > -8 else { return }

        // Speed filter: reject locations implying faster than ~25 mph (sprinter max).
        // CLLocation.speed is -1 when unavailable, so only apply when valid.
        if userLocation.speed >= 0, userLocation.speed > 11 { return }

        if let lastCoord = breadcrumbs.last {
            let lastLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let stepDistance = userLocation.distance(from: lastLoc)

            // Filter micro-movements: GPS jitter when stationary can otherwise
            // accumulate phantom distance over time.
            guard stepDistance >= 5 else { return }

            trackedDistanceMeters += stepDistance
            breadcrumbs.append(userLocation.coordinate)
        } else {
            // First breadcrumb of the run.
            breadcrumbs.append(userLocation.coordinate)
        }

        // Also update route progress for turn-by-turn (route runs only).
        progress?.update(userLocation: userLocation)

        // When current leg is done, pop the next one seamlessly.
        if progress?.hasArrived == true, !pendingLegs.isEmpty {
            let next = pendingLegs.removeFirst()
            currentLegIndex += 1
            progress = RouteProgress(route: next)
        }
    }

    // MARK: Stats

    var distanceCoveredMeters: Double { trackedDistanceMeters }
    var distanceCoveredMiles: Double { trackedDistanceMeters / 1609.34 }

    /// Remaining distance along the planned route. `nil` for free runs.
    var remainingMeters: Double? {
        guard let p = progress else { return nil }
        let pendingDistance = pendingLegs.reduce(0) { $0 + $1.distance }
        return p.remainingDistance + pendingDistance
    }

    /// Combined planned coordinates for all legs (for history map display).
    var allPlannedCoordinates: [CLLocationCoordinate2D] {
        let outbound = route?.polyline.coordinates ?? []
        return outbound + allPendingLegCoords.flatMap { $0 }
    }
    var remainingMiles: Double? {
        remainingMeters.map { $0 / 1609.34 }
    }

    /// Rough calorie estimate for walking. ~80 kcal per mile for a ~70kg adult.
    var caloriesBurned: Double {
        distanceCoveredMiles * 80
    }

    /// Pace in minutes per mile. `nil` until the user has covered enough
    /// ground to give a meaningful number, and filtered to a realistic range.
    var paceMinutesPerMile: Double? {
        guard distanceCoveredMiles >= 0.05 else { return nil }
        let minutes = elapsedTime / 60
        let pace = minutes / distanceCoveredMiles
        guard pace >= 2, pace < 60 else { return nil }
        return pace
    }

    /// True when the user has effectively reached the route's finish.
    /// Always false for free runs.
    var hasArrived: Bool {
        progress?.hasArrived ?? false
    }
}

// MARK: - Completed run (history item)

struct CompletedRun: Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    let distanceMeters: Double
    let caloriesBurned: Double

    /// Actual GPS breadcrumbs of the run. May be empty if the user didn't
    /// move or GPS never produced acceptable readings.
    let pathCoordinates: [CLLocationCoordinate2D]

    /// The originally-generated route polyline, if any. Always `nil` for free runs.
    let plannedRouteCoordinates: [CLLocationCoordinate2D]?

    /// The finish-line location for route-based runs.
    let destination: CLLocationCoordinate2D?

    /// Activity type label: "Free Run", "Route Run", "Outdoor Walk", "Indoor Walk"
    var workoutType: String

    var isFreeRun: Bool { plannedRouteCoordinates == nil }
    var isWalk: Bool { workoutType.contains("Walk") }

    /// Coordinates to display on the map. Prefers actual GPS track; if none
    /// was recorded, falls back to the planned route (for route-based runs).
    var displayCoordinates: [CLLocationCoordinate2D] {
        pathCoordinates.isEmpty ? (plannedRouteCoordinates ?? []) : pathCoordinates
    }

    var distanceMiles: Double { distanceMeters / 1609.34 }

    /// Average pace in minutes per mile — `nil` when the run was too short
    /// or the number works out to something unrealistic.
    var averagePaceMinutesPerMile: Double? {
        guard distanceMiles >= 0.1 else { return nil }
        let pace = (durationSeconds / 60) / distanceMiles
        guard pace >= 2, pace < 60 else { return nil }
        return pace
    }
}

// MARK: - Store

/// App-level store that holds the active session and completed run history.
/// Injected into the environment by `nameRunnerApp`.
@Observable
final class RunStore {
    var activeSession: RunSession?
    var history: [CompletedRun] = []
    var lastCompletedRun: CompletedRun?
    var shouldShowCompletionCelebration: Bool = false
    var isLoadingHistory: Bool = false

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func startRouteRun(route: MKRoute, destination: CLLocationCoordinate2D?) {
        activeSession = RunSession(route: route, destination: destination)
    }

    func startLoopRun(legs: [MKRoute], origin: CLLocationCoordinate2D) {
        guard let first = legs.first else { return }
        activeSession = RunSession(route: first, destination: origin, pendingLegs: Array(legs.dropFirst()))
    }

    func startBuiltRun(legs: [MKRoute], destination: CLLocationCoordinate2D) {
        guard let first = legs.first else { return }
        activeSession = RunSession(route: first, destination: destination, pendingLegs: Array(legs.dropFirst()))
    }

    func startFreeRun() {
        activeSession = RunSession(route: nil, destination: nil)
    }

    func endActiveRun() {
        finalizeActiveRun(celebrate: false)
    }

    func completeActiveRunAtFinish() {
        finalizeActiveRun(celebrate: true)
    }

    /// Fetches the signed-in user's run history from Firestore.
    func loadHistory() {
        guard let uid = authManager.currentUser?.uid else { return }
        isLoadingHistory = true
        Task { @MainActor in
            defer { isLoadingHistory = false }
            do {
                history = try await FirestoreService.loadRuns(for: uid)
            } catch {
                // Network failure — leave existing history in place.
            }
        }
    }

    func clearHistory() {
        history = []
    }

    func deleteRun(id: UUID) {
        history.removeAll { $0.id == id }
        if let uid = authManager.currentUser?.uid {
            Task { try? await FirestoreService.deleteRun(id: id, for: uid) }
        }
    }

    private func finalizeActiveRun(celebrate: Bool) {
        guard let session = activeSession else { return }
        session.pause()

        let distanceMiles = session.distanceCoveredMeters / 1609.34
        let isMeaningful = distanceMiles >= 0.20 || session.elapsedTime >= 120

        let completed = CompletedRun(
            id: session.id,
            date: session.startedAt,
            durationSeconds: session.elapsedTime,
            distanceMeters: session.distanceCoveredMeters,
            caloriesBurned: session.caloriesBurned,
            pathCoordinates: session.breadcrumbs,
            plannedRouteCoordinates: session.allPlannedCoordinates.isEmpty ? nil : session.allPlannedCoordinates,
            destination: session.destination,
            workoutType: session.isFreeRun ? "Free Run" : "Route Run"
        )

        // Always show the summary, but only save to history if the run is meaningful.
        if isMeaningful {
            history.insert(completed, at: 0)
        }
        lastCompletedRun = completed
        activeSession = nil

        if celebrate {
            shouldShowCompletionCelebration = true
        }

        if isMeaningful, let uid = authManager.currentUser?.uid {
            let miles = completed.distanceMiles
            let name = authManager.displayName ?? "Runner"
            Task {
                try? await FirestoreService.saveRun(completed, for: uid)
                try? await FriendsService.updateUserStats(uid: uid, displayName: name, addedMiles: miles)
            }
        }
    }
}
