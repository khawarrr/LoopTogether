//
//  LoopTogetherWidgetLiveActivity.swift
//  LoopTogetherWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LoopTogetherWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } compactTrailing: {
                Text(String(format: "%.2f mi", context.state.distanceMiles))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .keylineTint(.blue)
        }
    }

    // MARK: - Lock Screen

    private func lockScreenView(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: context.state.isPaused ? "pause.circle.fill" : "figure.run.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.runType)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(context.state.isPaused ? "Paused" : "Running")
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.startDate, style: .timer)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(context.state.isPaused ? .orange : .primary)

                Text(String(format: "%.2f mi", context.state.distanceMiles))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(uiColor: .systemBackground))
        .activitySystemActionForegroundColor(.blue)
    }

    // MARK: - Dynamic Island Expanded

    private func expandedLeading(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.runType)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(context.attributes.startDate, style: .timer)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(context.state.isPaused ? .orange : .primary)
        }
        .padding(.leading, 4)
    }

    private func expandedTrailing(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Distance")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f mi", context.state.distanceMiles))
                .font(.title2.bold())
                .monospacedDigit()
        }
        .padding(.trailing, 4)
    }

    private func expandedBottom(context: ActivityViewContext<RunActivityAttributes>) -> some View {
        HStack {
            if context.state.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            } else if context.state.paceMinPerMile > 0 {
                Label(paceString(context.state.paceMinPerMile), systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .monospacedDigit()
            } else {
                Label("Warming up…", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "figure.run")
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func paceString(_ pace: Double) -> String {
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d /mi", m, s)
    }
}
