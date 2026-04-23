//
//  RunDetailView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import MapKit
import CoreLocation

/// Detail view for a completed run from history.
/// Shows the actual GPS path (or planned route as fallback) on a map,
/// plus summary stats.
struct RunDetailView: View {
    let run: CompletedRun
    @Environment(AppSettings.self) private var settings

    @State private var position: MapCameraPosition

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(run: CompletedRun) {
        self.run = run

        let coords = run.displayCoordinates
        let region: MKCoordinateRegion
        if !coords.isEmpty {
            let polyline = MKPolyline(
                coordinates: coords,
                count: coords.count
            )
            let rect = polyline.boundingMapRect
            let padded = rect.insetBy(
                dx: -rect.size.width * 0.15,
                dy: -rect.size.height * 0.15
            )
            region = MKCoordinateRegion(padded)
        } else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !run.isWalk {
                mapOrPlaceholder
            }
            statsCard
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleText: String {
        let date = Self.dateFormatter.string(from: run.date)
        return run.isWalk ? "\(run.workoutType) · \(date)"
             : run.isFreeRun ? "Free Run · \(date)"
             : "Route Run · \(date)"
    }

    // MARK: - Map / placeholder

    @ViewBuilder
    private var mapOrPlaceholder: some View {
        if run.displayCoordinates.isEmpty {
            ContentUnavailableView(
                "No path recorded",
                systemImage: "map.slash",
                description: Text("GPS didn't record any movement for this run.")
            )
            .frame(maxHeight: .infinity)
        } else {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                MapPolyline(coordinates: run.displayCoordinates)
                    .stroke(.blue, lineWidth: 5)

                if let start = run.displayCoordinates.first {
                    Marker("Start", systemImage: "flag.fill", coordinate: start)
                        .tint(.green)
                }

                // Finish marker: prefer planned destination; otherwise use
                // the last breadcrumb (only meaningful if they actually moved).
                if let destination = run.destination {
                    Marker("Finish", systemImage: "flag.checkered", coordinate: destination)
                        .tint(.red)
                } else if run.displayCoordinates.count > 1,
                          let last = run.displayCoordinates.last {
                    Marker("End", systemImage: "flag.checkered", coordinate: last)
                        .tint(.red)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                statTile(
                    icon: "map.fill",
                    value: String(format: "%.2f", settings.useMetric ? run.distanceMeters / 1000 : run.distanceMiles),
                    unit: settings.useMetric ? "km" : "miles"
                )
                statTile(
                    icon: "clock.fill",
                    value: ActiveRunCard.timeString(run.durationSeconds),
                    unit: "duration"
                )
            }
            HStack(spacing: 10) {
                statTile(
                    icon: "bolt.fill",
                    value: paceString(run.averagePaceMinutesPerMile),
                    unit: "min/mi"
                )
                statTile(
                    icon: "flame.fill",
                    value: String(format: "%.0f", run.caloriesBurned),
                    unit: "calories"
                )
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private func statTile(icon: String, value: String, unit: String) -> some View {
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
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func paceString(_ pace: Double?) -> String {
        guard let pace else { return "--" }
        return settings.formatPace(pace)
    }
}
