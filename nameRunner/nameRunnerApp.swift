//
//  nameRunnerApp.swift
//  nameRunner
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

@main
struct nameRunnerApp: App {
    @State private var authManager: AuthManager
    @State private var runStore: RunStore
    @State private var locationManager: LocationManager
    @State private var phoneSession: PhoneSessionManager
    @State private var profileImageManager = ProfileImageManager()

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
