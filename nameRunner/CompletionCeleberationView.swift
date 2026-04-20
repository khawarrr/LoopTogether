//
//  CompletionCelebrationView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI

/// Celebration shown when a runner successfully reaches the planned finish.
/// Displays the summary stats and offers a way into the full run detail.
struct CompletionCelebrationView: View {
    let run: CompletedRun
    let onViewDetails: () -> Void
    let onDismiss: () -> Void

    // Pick a rotating headline so repeated runs don't feel stale.
    @State private var headline: String = CompletionCelebrationView.randomHeadline()
    @State private var trophyBounce = false
    @State private var confettiPulse = false

    private static let celebrationHeadlines = [
        "You crushed it!",
        "Great run!",
        "Another one in the books!",
        "Nice work out there!",
        "Run complete!",
        "Way to finish strong!",
        "That's a wrap!",
    ]

    private static func randomHeadline() -> String {
        celebrationHeadlines.randomElement() ?? "Great run!"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.14), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle pulsing confetti behind the trophy. Pure SF Symbols so
            // it works offline, no image assets needed.
            confettiBackdrop
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                Spacer()

                // Trophy
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: 120, height: 120)
                        .scaleEffect(trophyBounce ? 1.08 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: trophyBounce
                        )
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, value: trophyBounce)
                }

                // Headline + subtitle
                VStack(spacing: 6) {
                    Text(headline)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("You finished your run")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Summary stats grid
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        summaryTile(
                            icon: "map.fill",
                            value: String(format: "%.2f", run.distanceMiles),
                            unit: "miles"
                        )
                        summaryTile(
                            icon: "clock.fill",
                            value: ActiveRunCard.timeString(run.durationSeconds),
                            unit: "duration"
                        )
                    }
                    HStack(spacing: 10) {
                        summaryTile(
                            icon: "bolt.fill",
                            value: paceString(run.averagePaceMinutesPerMile),
                            unit: "min/mi"
                        )
                        summaryTile(
                            icon: "flame.fill",
                            value: String(format: "%.0f", run.caloriesBurned),
                            unit: "calories"
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Actions
                VStack(spacing: 10) {
                    Button(action: onViewDetails) {
                        Label("View Details", systemImage: "map")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                    Button(action: onDismiss) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding()
        }
        .onAppear {
            trophyBounce = true
            confettiPulse = true
        }
    }

    // MARK: - Subviews

    private var confettiBackdrop: some View {
        // Fixed pseudo-random offsets — deterministic so symbols don't
        // jump on every re-render but still feel scattered.
        let icons: [(String, Color, CGFloat, CGFloat, Double)] = [
            ("sparkle", .yellow, -140, -260, 0.0),
            ("sparkle", .blue, 130, -220, 0.2),
            ("star.fill", .orange, -100, -120, 0.4),
            ("sparkle", .pink, 120, -80, 0.6),
            ("star.fill", .yellow, -150, 40, 0.8),
            ("sparkle", .purple, 140, 120, 1.0),
            ("star.fill", .blue, -120, 200, 1.2),
            ("sparkle", .orange, 110, 260, 1.4),
        ]

        return ZStack {
            ForEach(icons.indices, id: \.self) { i in
                let item = icons[i]
                Image(systemName: item.0)
                    .font(.system(size: 22))
                    .foregroundStyle(item.1.opacity(0.55))
                    .offset(x: item.2, y: item.3)
                    .scaleEffect(confettiPulse ? 1.15 : 0.85)
                    .opacity(confettiPulse ? 1.0 : 0.55)
                    .animation(
                        .easeInOut(duration: 1.6)
                            .repeatForever(autoreverses: true)
                            .delay(item.4),
                        value: confettiPulse
                    )
            }
        }
    }

    private func summaryTile(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func paceString(_ pace: Double?) -> String {
        guard let pace else { return "--" }
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d", m, s)
    }
}
