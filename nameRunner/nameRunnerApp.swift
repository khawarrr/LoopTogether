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

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        let auth = AuthManager()
        _authManager = State(initialValue: auth)
        _runStore = State(initialValue: RunStore(authManager: auth))
        _locationManager = State(initialValue: LocationManager())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(runStore)
                .environment(locationManager)
                .environment(authManager)
                .onAppear {
                    locationManager.requestPermission()
                    // Load history if the user was already signed in from a previous session.
                    if authManager.isSignedIn {
                        runStore.loadHistory()
                    }
                }
                .onChange(of: authManager.currentUser?.uid) { _, uid in
                    if uid != nil {
                        runStore.loadHistory()
                    } else {
                        runStore.clearHistory()
                    }
                }
        }
    }
}
