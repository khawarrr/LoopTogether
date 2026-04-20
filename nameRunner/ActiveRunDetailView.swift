//
//  ActiveRunDetailView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import MapKit
import CoreLocation

/// The "I'm running" screen.
/// - Map on top showing the route (if any) + live GPS breadcrumb trail.
/// - Turn banner overlay for route runs (shows next maneuver + distance).
/// - Big pausable timer.
/// - Three stat tiles.
/// - Pause/Resume + End controls.
/// - For route runs: secondary button to open focus navigation view.
struct ActiveRunDetailView: View {
    let session: RunSession

    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var runStore
    @Environment(LocationManager.self) private var locationManager
    @Environment(SpeechAnnouncer.self) private var announcer

    @State private var position: MapCameraPosition
    @State private var showNav = false
    @State private var confirmEnd = false

    private static let distanceFormatter: MKDistanceFormatter = {
        let f = MKDistanceFormatter()
        f.units = .imperial
        f.unitStyle = .abbreviated
        return f
    }()

    init(session: RunSession) {
        self.session = session

        let fallbackCenter: CLLocationCoordinate2D
        if let start = session.route?.polyline.coordinates.first {
            fallbackCenter = start
        } else {
            // Free run: we don't have a planned start; userLocation will take over
            fallbackCenter = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        }
        let fallback = MKCoordinateRegion(
            center: fallbackCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        _position = State(initialValue: .userLocation(fallback: .region(fallback)))
    }

    var body: some View {
        @Bindable var announcer = announcer

        NavigationStack {
            VStack(spacing: 0) {
                mapView
                statsPanel
            }
            .navigationTitle(session.isFreeRun ? "Free Run" : "Active Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.down")
                    }
                }
                if !session.isFreeRun {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            announcer.isMuted.toggle()
                        } label: {
                            Image(systemName: announcer.isMuted
                                  ? "speaker.slash.fill"
                                  : "speaker.wave.2.fill")
                        }
                        .accessibilityLabel(
                            announcer.isMuted ? "Unmute directions" : "Mute directions"
                        )
                    }
                }
            }
            .confirmationDialog(
                "End this run?",
                isPresented: $confirmEnd,
                titleVisibility: .visible
            ) {
                Button("End Run", role: .destructive) {
                    runStore.completeActiveRunAtFinish()
                }
                Button("Keep Running", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showNav) {
                NavigationRunView(
                    session: session,
                    locationManager: locationManager
                )
            }
            // If the run is auto-completed (arrival), the store clears
            // `activeSession`. Dismiss this cover so the celebration sheet
            // from RootTabView can take over cleanly.
            .onChange(of: runStore.activeSession?.id) { _, newId in
                if newId == nil {
                    dismiss()
                }
            }
            .onAppear {
                guard !session.isFreeRun else { return }
                locationManager.startHeadingUpdates()
                if let loc = locationManager.currentLocation {
                    position = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 300,
                        heading: 0,
                        pitch: 45
                    ))
                }
            }
            .onDisappear {
                locationManager.stopHeadingUpdates()
            }
            .onChange(of: locationManager.currentLocation) { _, loc in
                guard !session.isFreeRun, let loc else { return }
                let hdg = navHeading
                withAnimation(.linear(duration: 0.5)) {
                    position = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 300,
                        heading: hdg,
                        pitch: 45
                    ))
                }
            }
            .onChange(of: locationManager.heading) { _, _ in
                guard !session.isFreeRun,
                      let loc = locationManager.currentLocation else { return }
                withAnimation(.linear(duration: 0.3)) {
                    position = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 300,
                        heading: navHeading,
                        pitch: 45
                    ))
                }
            }
        }
    }

    private var navHeading: Double {
        guard let h = locationManager.heading else { return 0 }
        return h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $position) {
            UserAnnotation()

            // Planned route — adapts to system theme for light/dark contrast
            if let route = session.route {
                MapPolyline(route)
                    .stroke(Color.primary.opacity(0.35), lineWidth: 4)
            }

            // Actual GPS breadcrumbs — solid blue core with a white halo
            // for contrast on any map style.
            if session.breadcrumbs.count >= 2 {
                MapPolyline(coordinates: session.breadcrumbs)
                    .stroke(.white, lineWidth: 8)
                MapPolyline(coordinates: session.breadcrumbs)
                    .stroke(.blue, lineWidth: 5)
            }

            if let dest = session.destination {
                Marker("Finish", coordinate: dest)
                    .tint(.red)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .top) {
            turnBanner
                .padding(.horizontal, 12)
                .padding(.top, 6)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var turnBanner: some View {
        if !session.isFreeRun, let progress = session.progress {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName(for: progress.upcomingInstruction))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    if !progress.hasArrived, progress.distanceToNextTurn > 0 {
                        Text("In \(Self.distanceFormatter.string(fromDistance: progress.distanceToNextTurn))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Text(progress.upcomingInstruction.isEmpty ? "Starting…" : progress.upcomingInstruction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(12)
            .shadow(radius: 3)
        }
    }

    // MARK: - Stats panel

    private var statsPanel: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(spacing: 4) {
                    Text(ActiveRunCard.timeString(session.elapsedTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(session.isPaused ? "paused" : "duration")
                        .font(.caption)
                        .foregroundStyle(session.isPaused ? .orange : .secondary)
                        .textCase(.uppercase)
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HStack(spacing: 10) {
                    if session.isFreeRun {
                        StatTile(
                            icon: "figure.run",
                            value: String(format: "%.2f", session.distanceCoveredMiles),
                            unit: "mi"
                        )
                    } else {
                        StatTile(
                            icon: "arrow.forward.circle.fill",
                            value: String(format: "%.2f", session.distanceCoveredMiles),
                            unit: "mi done"
                        )
                        StatTile(
                            icon: "flag.checkered",
                            value: String(format: "%.2f", session.remainingMiles ?? 0),
                            unit: "mi left"
                        )
                    }
                    StatTile(
                        icon: "flame.fill",
                        value: String(format: "%.0f", session.caloriesBurned),
                        unit: "cal"
                    )
                    StatTile(
                        icon: "bolt.fill",
                        value: paceString(session.paceMinutesPerMile),
                        unit: "min/mi"
                    )
                }
            }

            HStack(spacing: 10) {
                Button {
                    if session.isPaused {
                        session.resume()
                    } else {
                        session.pause()
                    }
                } label: {
                    Label(
                        session.isPaused ? "Resume" : "Pause",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .background(session.isPaused ? Color.green : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)

                Button {
                    confirmEnd = true
                } label: {
                    Text("End")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                }
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if !session.isFreeRun {
                Button {
                    showNav = true
                } label: {
                    Label("Focus Navigation", systemImage: "location.north.line.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func paceString(_ pace: Double?) -> String {
        guard let pace, pace.isFinite, pace > 0, pace < 60 else { return "--" }
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d", m, s)
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

// MARK: - Stat tile

struct StatTile: View {
    let icon: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3.bold())
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
}
