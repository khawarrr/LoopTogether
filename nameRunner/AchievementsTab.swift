//
//  AchievementsTab.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI

struct AchievementsTab: View {
    @Environment(RunStore.self) private var runStore

    private var totalRuns: Int { runStore.history.count }
    private var totalMiles: Double {
        runStore.history.reduce(0) { $0 + $1.distanceMiles }
    }
    private var totalSeconds: TimeInterval {
        runStore.history.reduce(0) { $0 + $1.durationSeconds }
    }
    private var totalCalories: Double {
        runStore.history.reduce(0) { $0 + $1.caloriesBurned }
    }
    private var longestMiles: Double {
        runStore.history.map(\.distanceMiles).max() ?? 0
    }

    /// Simple milestone badges based on aggregate stats.
    private var badges: [(title: String, subtitle: String, icon: String, unlocked: Bool)] {
        [
            ("First Run", "Complete your first run", "flag.fill", totalRuns >= 1),
            ("5 Total Miles", "Rack up 5 miles across all runs", "figure.run", totalMiles >= 5),
            ("10 Total Miles", "Rack up 10 miles across all runs", "figure.run.circle.fill", totalMiles >= 10),
            ("5-Mile Run", "Complete a single run of 5 mi+", "star.fill", longestMiles >= 5),
            ("10 Runs", "Finish 10 separate runs", "medal.fill", totalRuns >= 10),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Totals") {
                    statRow(icon: "figure.run", label: "Runs completed", value: "\(totalRuns)")
                    statRow(icon: "map.fill", label: "Distance", value: String(format: "%.2f mi", totalMiles))
                    statRow(icon: "clock.fill", label: "Time", value: ActiveRunCard.timeString(totalSeconds))
                    statRow(icon: "flame.fill", label: "Calories", value: String(format: "%.0f", totalCalories))
                }

                Section("Badges") {
                    ForEach(badges, id: \.title) { badge in
                        badgeRow(badge)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Achievements")
        }
    }

    // MARK: - Row builders

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.blue)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func badgeRow(_ badge: (title: String, subtitle: String, icon: String, unlocked: Bool)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(badge.unlocked ? Color.yellow.opacity(0.18) : Color.gray.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: badge.icon)
                    .font(.title3)
                    .foregroundStyle(badge.unlocked ? .yellow : .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title).font(.body)
                Text(badge.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if badge.unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let auth = AuthManager()
    AchievementsTab()
        .environment(RunStore(authManager: auth))
        .environment(auth)
}
