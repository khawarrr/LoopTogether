//
//  DailyChallengesSection.swift
//  nameRunner
//

import SwiftUI

struct DailyChallengesSection: View {
    let stepsToday: Int
    let todayRuns: [CompletedRun]

    private var todayMiles: Double { todayRuns.reduce(0) { $0 + $1.distanceMiles } }
    private var todayMinutes: Double { todayRuns.reduce(0) { $0 + $1.durationSeconds / 60 } }
    private var longestRunMiles: Double { todayRuns.map(\.distanceMiles).max() ?? 0 }

    private var challenges: [DailyChallenge] {
        [
            DailyChallenge(
                icon: "figure.run",
                title: "Run 1 Mile",
                current: todayMiles,
                target: 1.0,
                unit: "mi"
            ),
            DailyChallenge(
                icon: "shoeprints.fill",
                title: "Walk 10,000 Steps",
                current: Double(stepsToday),
                target: 10_000,
                unit: "steps",
                formatCurrent: { Int($0).formatted() },
                formatTarget: { _ in "10,000" }
            ),
            DailyChallenge(
                icon: "trophy.fill",
                title: "Complete a 5K",
                current: longestRunMiles,
                target: 3.107,
                unit: "mi"
            ),
            DailyChallenge(
                icon: "clock.fill",
                title: "Stay Active 20 Min",
                current: todayMinutes,
                target: 20,
                unit: "min",
                formatCurrent: { String(format: "%.0f", $0) },
                formatTarget: { _ in "20" }
            )
        ]
    }

    var body: some View {
        Section("Daily Challenges") {
            ForEach(challenges) { challenge in
                ChallengeRow(challenge: challenge)
            }
        }
    }
}

// MARK: - Model

struct DailyChallenge: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let current: Double
    let target: Double
    let unit: String
    var formatCurrent: ((Double) -> String)?
    var formatTarget: ((Double) -> String)?

    var isCompleted: Bool { current >= target }
    var progress: Double { min(current / target, 1.0) }

    var currentText: String { formatCurrent?(current) ?? String(format: "%.2f", current) }
    var targetText: String { formatTarget?(target) ?? String(format: "%.2f", target) }
}

// MARK: - Row

private struct ChallengeRow: View {
    let challenge: DailyChallenge

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: challenge.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 5)
                        Capsule()
                            .fill(iconColor)
                            .frame(width: geo.size.width * challenge.progress, height: 5)
                    }
                }
                .frame(height: 5)

                Text("\(challenge.currentText) / \(challenge.targetText) \(challenge.unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if challenge.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        challenge.isCompleted ? .green : .blue
    }
}
