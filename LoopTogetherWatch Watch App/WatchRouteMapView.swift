//
//  WatchRouteMapView.swift
//  LoopTogetherWatch Watch App
//

import SwiftUI
import MapKit

struct WatchRouteMapView: View {
    @Environment(WatchWorkoutManager.self) private var workout

    @State private var position: MapCameraPosition = .automatic
    @State private var headingUp = true
    @State private var overviewMode = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let route = workout.currentRoute else { return [] }
        return route.steps.map {
            CLLocationCoordinate2D(latitude: $0.endCoordinate.latitude,
                                   longitude: $0.endCoordinate.longitude)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $position, interactionModes: []) {
                if !routeCoordinates.isEmpty {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(.blue, lineWidth: 3)

                    if let first = routeCoordinates.first {
                        Annotation("Start", coordinate: first) {
                            Circle().fill(.green).frame(width: 10, height: 10)
                        }
                    }
                    if let dest = workout.currentRoute?.destination {
                        Annotation("End", coordinate: CLLocationCoordinate2D(
                            latitude: dest.latitude, longitude: dest.longitude)) {
                            Image(systemName: "flag.checkered.circle.fill")
                                .foregroundStyle(.red).font(.system(size: 16))
                        }
                    }
                }

                if let coord = workout.currentCoordinate {
                    Annotation("You", coordinate: coord) {
                        Button {
                            if overviewMode {
                                overviewMode = false
                                updateFollowCamera()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(overviewMode ? .orange : .white)
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .fill(overviewMode ? .white : .blue)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onChange(of: workout.currentCoordinate?.latitude) { _, _ in
                if !overviewMode { updateFollowCamera() }
            }
            .onChange(of: workout.currentHeading) { _, _ in
                if !overviewMode && headingUp { updateFollowCamera() }
            }

            VStack(spacing: 6) {
                // Compass / heading toggle
                Button {
                    headingUp.toggle()
                    if !overviewMode { updateFollowCamera() }
                } label: {
                    compassView
                }
                .buttonStyle(.plain)

                // Overview toggle
                Button {
                    overviewMode.toggle()
                    if overviewMode { showOverview() } else { updateFollowCamera() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(overviewMode ? .blue.opacity(0.9) : .black.opacity(0.6))
                            .frame(width: 32, height: 32)
                        Image(systemName: "map")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(6)
        }
    }

    // MARK: - Compass

    private var compassView: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.6))
                .frame(width: 32, height: 32)
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(headingUp ? .blue : .white)
                .rotationEffect(.degrees(headingUp ? 0 : -workout.currentHeading))
            if !headingUp {
                Text(cardinalDirection(workout.currentHeading))
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(y: 10)
            }
        }
    }

    // MARK: - Camera helpers

    private func updateFollowCamera() {
        guard let coord = workout.currentCoordinate else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .camera(MapCamera(
                centerCoordinate: coord,
                distance: 1200,
                heading: headingUp ? workout.currentHeading : 0,
                pitch: 0
            ))
        }
    }

    private func showOverview() {
        var coords = routeCoordinates
        if let current = workout.currentCoordinate { coords.append(current) }
        guard !coords.isEmpty else { return }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.4,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.4
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func cardinalDirection(_ heading: CLLocationDirection) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        return dirs[Int((heading + 22.5) / 45) % 8]
    }
}
