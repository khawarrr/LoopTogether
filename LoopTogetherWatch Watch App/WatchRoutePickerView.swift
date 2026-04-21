//
//  WatchRoutePickerView.swift
//  LoopTogetherWatch Watch App
//

import SwiftUI
import CoreLocation

struct WatchRoutePickerView: View {
    @Environment(WatchWorkoutManager.self) private var workout
    @Environment(\.dismiss) private var dismiss

    @State private var routeManager = WatchRouteManager()
    @State private var selectedMiles: Double = 3
    @State private var locationFetcher = WatchLocationFetcher()
    @State private var waitingForLocation = false

    private let distances: [Double] = [1, 2, 3, 5, 6.2]

    var body: some View {
        if routeManager.isGenerating || waitingForLocation {
            generatingView
        } else if let route = routeManager.generatedRoute {
            routeReadyView(route)
        } else {
            pickerView
        }
    }

    // MARK: - Picker

    private var pickerView: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Select Distance")
                    .font(.headline)
                    .padding(.bottom, 2)

                ForEach(distances, id: \.self) { d in
                    Button {
                        selectedMiles = d
                    } label: {
                        HStack {
                            Text(d == 6.2 ? "10K (6.2 mi)" : "\(String(format: "%.0f", d)) mile\(d == 1 ? "" : "s")")
                                .font(.body)
                            Spacer()
                            if selectedMiles == d {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.caption.bold())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                Button("Generate") {
                    generateRoute()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                if let err = routeManager.errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear { locationFetcher.start() }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(waitingForLocation ? "Getting location…" : "Generating route…")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !waitingForLocation {
                Text("Needs WiFi")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Route ready

    private func routeReadyView(_ route: WatchRoute) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)

            Text(String(format: "%.1f mi", route.totalDistanceMeters / 1609.34))
                .font(.headline)

            Text("\(route.steps.count) turns")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Retry") {
                    routeManager.generatedRoute = nil
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .controlSize(.small)

                Button("Start") {
                    workout.startRun(route: route)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func generateRoute() {
        if let loc = locationFetcher.location {
            Task { await routeManager.generate(targetMiles: selectedMiles, from: loc.coordinate) }
            return
        }
        // Wait up to 8 seconds for location to arrive
        waitingForLocation = true
        Task {
            for _ in 0..<16 {
                try? await Task.sleep(for: .milliseconds(500))
                if let loc = locationFetcher.location {
                    waitingForLocation = false
                    await routeManager.generate(targetMiles: selectedMiles, from: loc.coordinate)
                    return
                }
            }
            waitingForLocation = false
            routeManager.errorMessage = "Could not get location. Make sure Location is enabled for this app."
        }
    }
}

// Lightweight one-shot location fetcher for Watch
@Observable
final class WatchLocationFetcher: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    private let lm = CLLocationManager()

    func start() {
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        lm.requestWhenInUseAuthorization()
        lm.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy > 0 else { return }
        location = loc
        lm.stopUpdatingLocation()
    }
}
