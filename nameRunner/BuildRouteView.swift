//
//  BuildRouteView.swift
//  nameRunner
//

import SwiftUI
internal import MapKit
import CoreLocation

struct BuildRouteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var runStore
    @Environment(LocationManager.self) private var locationManager

    @State private var waypoints: [CLLocationCoordinate2D] = []
    @State private var legs: [MKRoute] = []
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    )
    @State private var hasCentered = false

    private var totalMiles: Double {
        legs.reduce(0) { $0 + $1.distance } / 1609.34
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapReader { proxy in
                    Map(position: $position) {
                        UserAnnotation()

                        ForEach(Array(waypoints.enumerated()), id: \.offset) { index, coord in
                            Annotation("\(index + 1)", coordinate: coord) {
                                ZStack {
                                    Circle()
                                        .fill(index == 0 ? Color.green : index == waypoints.count - 1 ? Color.red : Color.blue)
                                        .frame(width: 28, height: 28)
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        ForEach(Array(legs.enumerated()), id: \.offset) { _, leg in
                            MapPolyline(leg)
                                .stroke(.blue, lineWidth: 4)
                        }
                    }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                guard let coord = proxy.convert(value.location, from: .local) else { return }
                                addWaypoint(coord)
                            }
                    )
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .topTrailing) {
                        if !legs.isEmpty {
                            Button(action: frameFullRoute) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.top, 56)
                            .padding(.trailing, 12)
                        }
                    }
                }

                controlPanel
            }
            .navigationTitle("Build Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Undo") { removeLastWaypoint() }
                        .disabled(waypoints.isEmpty)
                }
            }
            .onAppear { centerOnUserIfNeeded() }
            .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
                centerOnUserIfNeeded()
            }
        }
    }

    // MARK: - Control panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            if waypoints.isEmpty {
                Text("Tap the map to place waypoints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isCalculating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Calculating route…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if legs.isEmpty {
                Text("\(waypoints.count) waypoint\(waypoints.count == 1 ? "" : "s") — add one more to build a route")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                HStack {
                    Label(String(format: "%.2f mi", totalMiles), systemImage: "map.fill")
                        .font(.subheadline.bold())
                    Spacer()
                    Label("\(waypoints.count) waypoints", systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            if !legs.isEmpty {
                Button(action: startRun) {
                    Label("Start Run", systemImage: "figure.run")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !waypoints.isEmpty {
                Button(action: clearAll) {
                    Text("Clear All")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
        .shadow(radius: 5)
    }

    // MARK: - Actions

    private func frameFullRoute() {
        guard let first = legs.first else { return }
        var rect = first.polyline.boundingMapRect
        for leg in legs.dropFirst() {
            rect = rect.union(leg.polyline.boundingMapRect)
        }
        let padded = rect.insetBy(dx: -rect.size.width * 0.25, dy: -rect.size.height * 0.25)
        withAnimation { position = .rect(padded) }
    }

    private func centerOnUserIfNeeded() {
        guard !hasCentered, let loc = locationManager.currentLocation else { return }
        position = .region(MKCoordinateRegion(
            center: loc.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        hasCentered = true
    }

    private func addWaypoint(_ coord: CLLocationCoordinate2D) {
        errorMessage = nil

        // Auto-insert current location as the starting waypoint on first tap.
        if waypoints.isEmpty, let userLoc = locationManager.currentLocation?.coordinate {
            waypoints.append(userLoc)
        }

        waypoints.append(coord)

        guard waypoints.count >= 2 else { return }

        let from = waypoints[waypoints.count - 2]
        let to = coord
        isCalculating = true

        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            request.transportType = .walking

            do {
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first {
                    legs.append(route)
                } else {
                    errorMessage = "No walking route found between those points."
                    waypoints.removeLast()
                }
            } catch {
                errorMessage = "Could not calculate route. Try a nearby point."
                waypoints.removeLast()
            }
            isCalculating = false
        }
    }

    private func removeLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !legs.isEmpty { legs.removeLast() }
        errorMessage = nil
    }

    private func clearAll() {
        waypoints.removeAll()
        legs.removeAll()
        errorMessage = nil
    }

    private func startRun() {
        guard let destination = waypoints.last else { return }
        runStore.startBuiltRun(legs: legs, destination: destination)
        dismiss()
    }
}
