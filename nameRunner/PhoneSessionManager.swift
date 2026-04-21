//
//  PhoneSessionManager.swift
//  nameRunner
//

import Foundation
import WatchConnectivity
import CoreLocation
import FirebaseAuth

@Observable
final class PhoneSessionManager: NSObject {
    var isWatchReachable = false

    private weak var runStore: RunStore?
    private weak var authManager: AuthManager?
    private var updateTask: Task<Void, Never>?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func configure(runStore: RunStore, authManager: AuthManager) {
        self.runStore = runStore
        self.authManager = authManager
        startUpdateLoop()
    }

    // MARK: - Private

    private func startUpdateLoop() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.pushRunState() }
            }
        }
    }

    private func pushRunState() {
        guard WCSession.default.isReachable, let store = runStore else { return }
        if let session = store.activeSession {
            WCSession.default.sendMessage([
                "phoneState": "active",
                "elapsed":    Int(session.elapsedTime),
                "distance":   session.distanceCoveredMeters,
                "pace":       session.paceMinutesPerMile ?? 0.0,
                "isPaused":   session.isPaused
            ], replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.sendMessage(["phoneState": "inactive"],
                                          replyHandler: nil, errorHandler: nil)
        }
    }

    @MainActor
    private func receiveWatchRun(_ data: WatchRunData) {
        guard let store = runStore, let auth = authManager else { return }

        let coords = data.pathCoordinates.compactMap { d -> CLLocationCoordinate2D? in
            guard let lat = d["lat"], let lng = d["lng"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let run = CompletedRun(
            id: UUID(),
            date: data.startDate,
            durationSeconds: data.durationSeconds,
            distanceMeters: data.distanceMeters,
            caloriesBurned: data.caloriesBurned,
            pathCoordinates: coords,
            plannedRouteCoordinates: nil,
            destination: nil
        )
        store.history.insert(run, at: 0)
        store.lastCompletedRun = run
        store.shouldShowCompletionCelebration = true

        if let uid = auth.currentUser?.uid {
            let miles = run.distanceMiles
            let name = auth.displayName ?? "Runner"
            Task {
                try? await FirestoreService.saveRun(run, for: uid)
                try? await FriendsService.updateUserStats(uid: uid, displayName: name, addedMiles: miles)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        Task { @MainActor [weak self] in
            guard let store = self?.runStore else { return }
            switch action {
            case "pause":  store.activeSession?.pause()
            case "resume": store.activeSession?.resume()
            case "end":    store.completeActiveRunAtFinish()
            default: break
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String, type == "completedRun",
              let data = WatchRunData.from(userInfo) else { return }
        Task { @MainActor in self.receiveWatchRun(data) }
    }
}
