//
//  ContentView.swift (WatchRootView)
//  LoopTogetherWatch Watch App
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchWorkoutManager.self) private var workout
    @Environment(WatchSessionManager.self) private var session

    var body: some View {
        Group {
            if workout.isActive {
                WatchActiveRunView(isWatchRun: true)
            } else if session.phoneIsActive {
                WatchActiveRunView(isWatchRun: false)
            } else {
                idleView
            }
        }
        .task { await workout.requestPermissions() }
    }

    @State private var showRoutePicker = false

    private var idleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.system(size: 34))
                .foregroundStyle(.blue)

            Text("LoopTogether")
                .font(.headline)

            Button("Free Run") {
                workout.startRun()
                session.sendAction("watchStartedRun")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button("Generate Route") {
                showRoutePicker = true
            }
            .buttonStyle(.bordered)
            .tint(.green)

            if session.phoneIsActive {
                Text("iPhone run active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showRoutePicker) {
            WatchRoutePickerView()
        }
    }
}
