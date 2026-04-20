//
//  RouteGenerator.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/18/26.
//

import Foundation
internal import MapKit
import Observation

/// Generates a random one-way walking route of a target distance from the user's location.
@Observable
class RouteGenerator {

    /// The generated walking route.
    var route: MKRoute?

    /// Whether a route generation is currently in progress.
    var isGenerating = false

    /// A user-facing error message, if something went wrong.
    var errorMessage: String?

    /// The bearing (degrees from north) used for the last generated route.
    var lastBearing: Double?

    /// The destination coordinate for the last generated route.
    var destination: CLLocationCoordinate2D?

    /// Actual distance of the generated route in miles.
    var routeDistanceMiles: Double {
        guard let route else { return 0 }
        return route.distance / 1609.34
    }

    // MARK: - Public API

    /// Generates a random walking route of roughly the given distance,
    /// starting from the given origin.
    @MainActor
    func generateRandomRoute(
        targetMiles: Double,
        from origin: CLLocationCoordinate2D
    ) async {
        isGenerating = true
        errorMessage = nil
        // Keep the old route visible while computing a new one — it's only
        // replaced if we successfully find a candidate.

        defer { isGenerating = false }

        // Walking routes along streets are typically 1.2–1.4× the straight-line
        // distance, so scale the target down when picking a destination point.
        let straightLineFactor = 0.8
        let straightLineMiles = targetMiles * straightLineFactor

        // Try several random bearings; keep the best one.
        var bestRoute: MKRoute?
        var bestBearing: Double?
        var bestDestination: CLLocationCoordinate2D?
        var bestDelta = Double.infinity

        for _ in 0..<5 {
            let bearing = Double.random(in: 0..<360)
            let candidate = destinationCoordinate(
                from: origin,
                bearing: bearing,
                distanceMiles: straightLineMiles
            )

            do {
                if let r = try await requestWalkingRoute(from: origin, to: candidate) {
                    let actualMiles = r.distance / 1609.34
                    let delta = abs(actualMiles - targetMiles)
                    if delta < bestDelta {
                        bestRoute = r
                        bestBearing = bearing
                        bestDestination = candidate
                        bestDelta = delta
                    }
                    // Good enough: within 15% of target, stop searching
                    if delta / targetMiles < 0.15 {
                        break
                    }
                }
            } catch {
                // Try another bearing
                continue
            }
        }

        if let bestRoute {
            route = bestRoute
            lastBearing = bestBearing
            destination = bestDestination
        } else if route == nil {
            // Only surface an error if we have no route at all to show
            errorMessage = "Could not generate a route here. Try a different distance."
        }
    }

    // MARK: - Private Helpers

    /// Requests a walking route between two coordinates, with retries for throttling.
    private func requestWalkingRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        retries: Int = 2
    ) async throws -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: origin.latitude, longitude: origin.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
            address: nil
        )
        request.transportType = .walking

        for attempt in 0...retries {
            do {
                let response = try await MKDirections(request: request).calculate()
                return response.routes.first
            } catch let error as MKError where error.code == .loadingThrottled {
                if attempt < retries {
                    try await Task.sleep(for: .seconds(1))
                } else {
                    throw error
                }
            }
        }
        return nil
    }

    /// Computes a destination coordinate given a starting point, compass bearing, and distance.
    /// Uses the great-circle (haversine) formula.
    private func destinationCoordinate(
        from origin: CLLocationCoordinate2D,
        bearing bearingDegrees: Double,
        distanceMiles: Double
    ) -> CLLocationCoordinate2D {
        let earthRadiusMiles = 3958.8
        let angularDistance = distanceMiles / earthRadiusMiles
        let bearing = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}
