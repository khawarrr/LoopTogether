//
//  WatchSessionManager.swift
//  LoopTogetherWatch Watch App
//

import Foundation
import WatchConnectivity

@Observable
final class WatchSessionManager: NSObject {
    // Mirrored state from iPhone (when phone starts a run)
    var phoneIsActive = false
    var phoneElapsed: Int = 0
    var phoneDistance: Double = 0
    var phonePace: Double = 0
    var phoneIsPaused = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendAction(_ action: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": action], replyHandler: nil, errorHandler: nil)
    }

    func transferRunData(_ data: WatchRunData) {
        WCSession.default.transferUserInfo(data.toDictionary())
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let state = message["phoneState"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.phoneIsActive = (state == "active")
            if state == "active" {
                self.phoneElapsed   = message["elapsed"]   as? Int    ?? 0
                self.phoneDistance  = message["distance"]  as? Double ?? 0
                self.phonePace      = message["pace"]      as? Double ?? 0
                self.phoneIsPaused  = message["isPaused"]  as? Bool   ?? false
            }
        }
    }
}
