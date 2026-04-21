//
//  WatchRouteManager.swift
//  LoopTogetherWatch Watch App
//

import Foundation
import MapKit
import CoreLocation

struct WatchRouteStep {
    let instruction: String
    let endCoordinate: CLLocationCoordinate2D
}

struct WatchRoute {
    let steps: [WatchRouteStep]
    let totalDistanceMeters: Double
    let destination: CLLocationCoordinate2D
}

@Observable
final class WatchRouteManager {
    var generatedRoute: WatchRoute?
    var isGenerating = false
    var errorMessage: String?

    @MainActor
    func generate(targetMiles: Double, from origin: CLLocationCoordinate2D) async {
        isGenerating = true
        errorMessage = nil
        generatedRoute = nil
        defer { isGenerating = false }

        let straightLineMiles = targetMiles * 0.8
        var bestRoute: MKRoute?
        var bestDelta = Double.infinity

        for _ in 0..<5 {
            let bearing = Double.random(in: 0..<360)
            let dest = destinationCoordinate(from: origin, bearing: bearing, distanceMiles: straightLineMiles)
            if let r = try? await requestRoute(from: origin, to: dest) {
                let delta = abs(r.distance / 1609.34 - targetMiles)
                if delta < bestDelta {
                    bestRoute = r
                    bestDelta = delta
                }
                if delta / targetMiles < 0.15 { break }
            }
        }

        guard let mkRoute = bestRoute else {
            errorMessage = "Could not generate a route. Make sure you're connected to WiFi."
            return
        }

        let steps = mkRoute.steps.compactMap { step -> WatchRouteStep? in
            guard !step.instructions.isEmpty else { return nil }
            let pts = step.polyline.points()
            let count = step.polyline.pointCount
            guard count > 0 else { return nil }
            let end = pts[count - 1].coordinate
            return WatchRouteStep(instruction: step.instructions, endCoordinate: end)
        }

        let lastPt = mkRoute.polyline.points()[mkRoute.polyline.pointCount - 1].coordinate
        generatedRoute = WatchRoute(
            steps: steps,
            totalDistanceMeters: mkRoute.distance,
            destination: lastPt
        )
    }

    // MARK: - Helpers

    private func requestRoute(from origin: CLLocationCoordinate2D,
                              to dest: CLLocationCoordinate2D) async throws -> MKRoute? {
        let req = MKDirections.Request()
        req.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        req.transportType = .walking
        return try await MKDirections(request: req).calculate().routes.first
    }

    private func destinationCoordinate(from origin: CLLocationCoordinate2D,
                                       bearing deg: Double,
                                       distanceMiles: Double) -> CLLocationCoordinate2D {
        let R = 3958.8
        let d = distanceMiles / R
        let b = deg * .pi / 180
        let lat1 = origin.latitude  * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let lat2 = asin(sin(lat1)*cos(d) + cos(lat1)*sin(d)*cos(b))
        let lon2 = lon1 + atan2(sin(b)*sin(d)*cos(lat1), cos(d) - sin(lat1)*sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / Double.pi, longitude: lon2 * 180 / Double.pi)
    }
}
