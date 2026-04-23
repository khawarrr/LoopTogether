//
//  nameRunnerApp.swift
//  nameRunner
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth
internal import _LocationEssentials

@main
struct nameRunnerApp: App {
    @State private var authManager: AuthManager
    @State private var runStore: RunStore
    @State private var locationManager: LocationManager
    @State private var phoneSession: PhoneSessionManager
    @State private var profileImageManager = ProfileImageManager()
    @State private var activityManager = RunActivityManager()

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        let auth = AuthManager()
        let store = RunStore(authManager: auth)
        let session = PhoneSessionManager()
        _authManager = State(initialValue: auth)
        _runStore = State(initialValue: store)
        _locationManager = State(initialValue: LocationManager())
        _phoneSession = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(runStore)
                .environment(locationManager)
                .environment(authManager)
                .environment(profileImageManager)
                .onAppear {
                    locationManager.requestPermission()
                    phoneSession.configure(runStore: runStore, authManager: authManager)
                    if authManager.isSignedIn {
                        runStore.loadHistory()
                    }
                }
                .onChange(of: runStore.activeSession?.id) { _, id in
                    if let session = runStore.activeSession {
                        locationManager.startBackgroundLocationUpdates()
                        activityManager.start(
                            runType: session.isFreeRun ? "Free Run" : "Route Run",
                            startDate: session.startedAt
                        )
                    } else {
                        locationManager.stopBackgroundLocationUpdates()
                        activityManager.end()
                    }
                }
                .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
                    guard let session = runStore.activeSession else { return }
                    activityManager.update(
                        distanceMiles: session.distanceCoveredMiles,
                        paceMinPerMile: session.paceMinutesPerMile ?? 0,
                        isPaused: session.isPaused
                    )
                }
                .onChange(of: authManager.currentUser?.uid) { _, uid in
                    if let uid {
                        runStore.loadHistory()
                        let name = authManager.displayName ?? authManager.currentUser?.email ?? "Runner"
                        Task { try? await FriendsService.ensureProfile(uid: uid, displayName: name) }
                    } else {
                        runStore.clearHistory()
                    }
                }
        }
    }
}
