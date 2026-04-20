//
//  NewRunView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import MapKit
import CoreLocation

/// Sheet presented from the Activities tab for generating a new route
/// and starting a route-based run.
struct NewRunView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var runStore
    @Environment(LocationManager.self) private var locationManager

    // Fallback region (LA) — only shown for a moment before we recenter on
    // the user's actual location via the explicit centering below.
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    /// Tracks whether we've already snapped the camera to the user's location
    /// at least once. Prevents us from fighting the user if they pan around
    /// (or overriding the framed route polyline once one is generated).
    @State private var hasCenteredOnUser = false

    @State private var targetMiles: Double = 3.0
    @State private var routeGenerator = RouteGenerator()

    private let fallbackCenter = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    UserAnnotation()

                    if let route = routeGenerator.route {
                        MapPolyline(route)
                            .stroke(.blue, lineWidth: 5)
                    }
                    if let destination = routeGenerator.destination {
                        Marker("Finish", coordinate: destination)
                            .tint(.red)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .bottom)

                controlCard
            }
            .navigationTitle("New Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Center on the user as soon as we have a fix. If one is already
            // available when the sheet opens, this fires immediately; if not,
            // the onChange below handles it when the first fix arrives.
            .onAppear { centerOnUserIfNeeded() }
            .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
                centerOnUserIfNeeded()
            }
        }
    }

    private var controlCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Distance:")
                Slider(value: $targetMiles, in: 0.1...30, step: 0.5)
                Text("\(targetMiles, specifier: "%.1f") mi")
                    .frame(width: 55, alignment: .trailing)
                    .monospacedDigit()
            }

            if routeGenerator.route != nil {
                Text("Route: \(routeGenerator.routeDistanceMiles, specifier: "%.2f") mi one way")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = routeGenerator.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if routeGenerator.route == nil {
                primaryButton(text: "Generate Route", action: generate)
            } else {
                primaryButton(
                    text: "Start Run",
                    systemImage: "figure.run",
                    action: startRun
                )
                secondaryButton(
                    text: "Try Another Route",
                    showSpinner: routeGenerator.isGenerating,
                    action: generate
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
        .shadow(radius: 5)
    }

    // MARK: - Buttons

    @ViewBuilder
    private func primaryButton(
        text: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if routeGenerator.isGenerating && routeGenerator.route == nil {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Label(text, systemImage: systemImage)
                } else {
                    Text(text)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(routeGenerator.isGenerating && routeGenerator.route == nil)
    }

    @ViewBuilder
    private func secondaryButton(
        text: String,
        showSpinner: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if showSpinner {
                    ProgressView()
                } else {
                    Text(text)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGray5))
        .foregroundColor(.primary)
        .cornerRadius(10)
        .disabled(showSpinner)
    }

    // MARK: - Actions

    /// Snaps the camera to the user's current location once per sheet opening.
    /// Skips if (a) we've already centered, (b) there's no fix yet, or (c) a
    /// route is already generated (the camera is framed on the route in that case).
    private func centerOnUserIfNeeded() {
        guard !hasCenteredOnUser,
              routeGenerator.route == nil,
              let loc = locationManager.currentLocation else { return }

        position = .region(MKCoordinateRegion(
            center: loc.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        hasCenteredOnUser = true
    }

    private func generate() {
        let center = locationManager.currentLocation?.coordinate ?? fallbackCenter

        Task {
            await routeGenerator.generateRandomRoute(
                targetMiles: targetMiles,
                from: center
            )

            if let route = routeGenerator.route {
                let rect = route.polyline.boundingMapRect
                let padded = rect.insetBy(
                    dx: -rect.size.width * 0.2,
                    dy: -rect.size.height * 0.2
                )
                position = .rect(padded)
            }
        }
    }

    private func startRun() {
        guard let route = routeGenerator.route else { return }
        runStore.startRouteRun(route: route, destination: routeGenerator.destination)
        dismiss()
    }
}

#Preview {
    let auth = AuthManager()
    NewRunView()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
