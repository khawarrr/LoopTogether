//
//  WatchRunSummaryView.swift
//  LoopTogetherWatch Watch App
//

import SwiftUI

struct WatchRunSummaryView: View {
    let data: WatchRunData
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)

                Text(data.workoutType)
                    .font(.headline)

                Divider()

                statRow(label: "Distance", value: String(format: "%.2f mi", data.distanceMeters / 1609.34))
                statRow(label: "Duration", value: timeString(data.durationSeconds))
                statRow(label: "Pace",     value: paceString(data.durationSeconds, meters: data.distanceMeters))
                statRow(label: "Calories", value: "\(Int(data.caloriesBurned)) kcal")
                if data.heartRate > 0 {
                    statRow(label: "Avg HR", value: "\(Int(data.heartRate)) bpm")
                }

                Divider()

                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }
            .padding(.vertical, 8)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }

    private func timeString(_ s: TimeInterval) -> String {
        let t = Int(s)
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%02d:%02d", m, sec)
    }

    private func paceString(_ duration: TimeInterval, meters: Double) -> String {
        guard meters > 50 else { return "--" }
        let miles = meters / 1609.34
        let pace = (duration / 60) / miles
        guard pace >= 2, pace < 60 else { return "--" }
        let m = Int(pace), s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d /mi", m, s)
    }
}
