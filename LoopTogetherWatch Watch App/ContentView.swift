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
            } else if let summary = workout.lastRun {
                WatchRunSummaryView(data: summary) {
                    workout.lastRun = nil
                }
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
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("LoopTogether")
                    .font(.headline)

                Button("Free Run") {
                    workout.startRun(mode: .freeRun)
                    session.sendAction("watchStartedRun")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Generate Route") {
                    showRoutePicker = true
                }
                .buttonStyle(.bordered)
                .tint(.green)

                HStack(spacing: 6) {
                    Button("Outdoor Walk") {
                        workout.startRun(mode: .outdoorWalk)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)

                    Button("Indoor Walk") {
                        workout.startRun(mode: .indoorWalk)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .font(.system(size: 13))

                if session.phoneIsActive {
                    Text("iPhone run active")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showRoutePicker) {
            WatchRoutePickerView()
        }
    }
}
