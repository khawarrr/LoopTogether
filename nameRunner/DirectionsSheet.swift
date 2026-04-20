//
//  DirectionsSheet.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import MapKit
import CoreLocation

/// A sheet showing the full turn-by-turn step list for a route.
/// Presented as a reference from the in-app navigation view.
struct DirectionsSheet: View {
    let route: MKRoute
    let destination: CLLocationCoordinate2D?

    @Environment(\.dismiss) private var dismiss

    private static let distanceFormatter: MKDistanceFormatter = {
        let f = MKDistanceFormatter()
        f.units = .imperial
        f.unitStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                // Summary
                Section {
                    HStack(spacing: 24) {
                        stat(
                            value: Self.distanceFormatter.string(fromDistance: route.distance),
                            label: "Distance"
                        )
                        Divider()
                        stat(
                            value: formattedTime(route.expectedTravelTime),
                            label: "Walking time"
                        )
                        Spacer()
                    }
                }

                // Step-by-step list
                Section("Turn by turn") {
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { _, step in
                        if !step.instructions.isEmpty {
                            stepRow(step: step)
                        }
                    }
                }
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row builders

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func stepRow(step: MKRoute.Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName(for: step.instructions))
                .font(.title3)
                .frame(width: 32, height: 32)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.instructions)
                if step.distance > 0 {
                    Text(Self.distanceFormatter.string(fromDistance: step.distance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    private func iconName(for instructions: String) -> String {
        let text = instructions.lowercased()
        if text.contains("arriv") || text.contains("destination") { return "flag.checkered" }
        if text.contains("u-turn") || text.contains("u turn") { return "arrow.uturn.down" }
        if text.contains("slight left") { return "arrow.up.left" }
        if text.contains("slight right") { return "arrow.up.right" }
        if text.contains("sharp left") { return "arrow.turn.up.left" }
        if text.contains("sharp right") { return "arrow.turn.up.right" }
        if text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("right") { return "arrow.turn.up.right" }
        return "arrow.up"
    }
}
