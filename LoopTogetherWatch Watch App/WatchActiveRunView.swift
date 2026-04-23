//
//  WatchActiveRunView.swift
//  LoopTogetherWatch Watch App
//

import SwiftUI

struct WatchActiveRunView: View {
    @Environment(WatchWorkoutManager.self) private var workout
    @Environment(WatchSessionManager.self) private var session

    let isWatchRun: Bool   // true = Watch GPS run, false = mirroring iPhone

    @State private var showEndConfirm = false

    private var elapsed: Int {
        isWatchRun ? workout.elapsedSeconds : session.phoneElapsed
    }
    private var distanceMeters: Double {
        isWatchRun ? workout.distanceMeters : session.phoneDistance
    }
    private var pace: Double {
        if isWatchRun {
            guard distanceMeters > 50, workout.elapsedSeconds > 0 else { return 0 }
            let miles = distanceMeters / 1609.34
            return (Double(workout.elapsedSeconds) / 60) / miles
        }
        return session.phonePace
    }
    private var isPaused: Bool {
        isWatchRun ? workout.isPaused : session.phoneIsPaused
    }

    var body: some View {
        if isWatchRun && workout.isRouteRun {
            TabView {
                statsPage
                WatchRouteMapView()
            }
            .tabViewStyle(.page)
            .background {
                WatchRouteMapView()
                    .opacity(0)
                    .allowsHitTesting(false)
            }
            .confirmationDialog(workout.hasArrivedAtDestination ? "You've arrived! End run?" : "End Run?",
                                isPresented: $showEndConfirm) {
                Button("End Run", role: .destructive) { handleEnd() }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: workout.hasArrivedAtDestination) { _, arrived in
                if arrived { showEndConfirm = true }
            }
        } else {
            statsPage
                .confirmationDialog(workout.hasArrivedAtDestination ? "You've arrived! End run?" : "End Run?",
                                    isPresented: $showEndConfirm) {
                    Button("End Run", role: .destructive) { handleEnd() }
                    Button("Cancel", role: .cancel) {}
                }
                .onChange(of: workout.hasArrivedAtDestination) { _, arrived in
                    if arrived { showEndConfirm = true }
                }
        }
    }

    private var statsPage: some View {
        VStack(spacing: 6) {
            // Elapsed time
            Text(timeString(elapsed))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPaused ? .orange : .primary)

            // Distance + Pace
            HStack(spacing: 14) {
                statView(value: String(format: "%.2f", distanceMeters / 1609.34), label: "mi")
                Divider().frame(height: 32)
                statView(value: pace > 0 ? paceString(pace) : "--:--", label: "pace")
            }

            // Heart rate + Calories row (Watch-only)
            if isWatchRun {
                HStack(spacing: 14) {
                    heartRateView
                    Divider().frame(height: 32)
                    caloriesView
                }
            }

            // Turn instruction (route runs only)
            if isWatchRun && workout.isRouteRun && !workout.currentInstruction.isEmpty {
                Text(workout.currentInstruction)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 2)
            }

            // Controls
            HStack(spacing: 10) {
                Button {
                    if isPaused {
                        if isWatchRun { workout.resumeRun() }
                        session.sendAction("resume")
                    } else {
                        if isWatchRun { workout.pauseRun() }
                        session.sendAction("pause")
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                }
                .tint(.orange)
                .buttonStyle(.bordered)

                Button {
                    showEndConfirm = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .tint(.red)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 4)
    }

    private func handleEnd() {
        if isWatchRun {
            Task {
                if let data = await workout.endRun() {
                    session.transferRunData(data)
                }
            }
        } else {
            session.sendAction("end")
        }
    }

    private var heartRateView: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                Text(workout.heartRate > 0 ? "\(Int(workout.heartRate))" : "--")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                    .monospacedDigit()
            }
            Text("bpm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var caloriesView: some View {
        let kcal = workout.calories > 0 ? workout.calories : (workout.distanceMeters / 1609.34) * 62
        return VStack(spacing: 2) {
            Text(kcal > 0 ? "\(Int(kcal))" : "--")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statView(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func timeString(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%02d:%02d", m, sec)
    }

    private func paceString(_ p: Double) -> String {
        let m = Int(p), s = Int((p - Double(m)) * 60)
        return String(format: "%d:%02d", m, s)
    }
}
