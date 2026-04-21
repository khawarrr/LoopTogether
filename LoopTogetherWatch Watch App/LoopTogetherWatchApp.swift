//
//  LoopTogetherWatchApp.swift
//  LoopTogetherWatch Watch App
//

import SwiftUI

@main
struct LoopTogetherWatch_Watch_AppApp: App {
    @State private var workoutManager = WatchWorkoutManager()
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(sessionManager)
        }
    }
}
