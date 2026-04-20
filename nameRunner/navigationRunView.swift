//
//  NavigationRunView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import MapKit
import CoreLocation

/// Full-screen "focus" navigation. A map that follows the user's heading,
/// with a prominent turn banner. Voice announcements are handled centrally
/// by `RootTabView`.
struct NavigationRunView: View {
    let session: RunSession
    let locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechAnnouncer.self) private var announcer

    @State private var position: MapCameraPosition
    @State private var showTurnList = false

    private static let distanceFormatter: MKDistanceFormatter = {
        let f = MKDistanceFormatter()
        f.units = .imperial
        f.unitStyle = .abbreviated
        return f
    }()

    init(session: RunSession, locationManager: LocationManager) {
        self.session = session
        self.locationManager = locationManager

        let start = session.route?.polyline.coordinates.first
            ?? CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let fallback = MKCoordinateRegion(
            center: start,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
        _position = State(initialValue: .userLocation(
            followsHeading: true,
            fallback: .region(fallback)
        ))
    }

    var body: some View {
        @Bindable var announcer = announcer

        ZStack {
            Map(position: $position) {
                UserAnnotation()

                // Planned route — blue with white halo for contrast on any map style
                if let route = session.route {
                    MapPolyline(route)
                        .stroke(.white, lineWidth: 9)
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 6)
                }

                // Breadcrumb trail on top, slightly different color so the
                // user can distinguish planned vs actual.
                if session.breadcrumbs.count >= 2 {
                    MapPolyline(coordinates: session.breadcrumbs)
                        .stroke(.white, lineWidth: 6)
                    MapPolyline(coordinates: session.breadcrumbs)
                        .stroke(Color.cyan, lineWidth: 3)
                }

                if let destination = session.destination {
                    Marker("Finish", coordinate: destination)
                        .tint(.red)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                turnBanner
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            locationManager.startHeadingUpdates()
        }
        .onDisappear {
            locationManager.stopHeadingUpdates()
        }
        .sheet(isPresented: $showTurnList) {
            if let route = session.route {
                DirectionsSheet(route: route, destination: session.destination)
            }
        }
    }

    // MARK: - Subviews

    private var turnBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: iconName(for: session.progress?.upcomingInstruction ?? ""))
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                if let progress = session.progress,
                   !progress.hasArrived,
                   progress.distanceToNextTurn > 0 {
                    Text("In \(Self.distanceFormatter.string(fromDistance: progress.distanceToNextTurn))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(session.progress?.upcomingInstruction ?? "")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.top, 8)
        .shadow(radius: 4)
    }

    private var bottomBar: some View {
        @Bindable var announcer = announcer

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.distanceFormatter.string(fromDistance: session.progress?.remainingDistance ?? 0))
                    .font(.title3.bold())
                    .monospacedDigit()
                Text("remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mute toggle
            Button {
                announcer.isMuted.toggle()
            } label: {
                Image(systemName: announcer.isMuted
                      ? "speaker.slash.fill"
                      : "speaker.wave.2.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .background(Color(.systemGray5))
            .foregroundColor(announcer.isMuted ? .red : .primary)
            .clipShape(Circle())
            .accessibilityLabel(
                announcer.isMuted ? "Unmute directions" : "Mute directions"
            )

            Button {
                showTurnList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .clipShape(Circle())

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .background(Color(.systemGray2))
            .foregroundColor(.white)
            .cornerRadius(22)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .shadow(radius: 4)
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
