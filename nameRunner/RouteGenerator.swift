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

    /// Remaining legs for loop routes (legs 2 and 3 of the triangle).
    var loopRemainingLegs: [MKRoute] = []

    /// Total distance of the generated route in miles (all legs combined).
    var routeDistanceMiles: Double {
        guard let route else { return 0 }
        let all = [route] + loopRemainingLegs
        return all.reduce(0) { $0 + $1.distance } / 1609.34
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

    /// Generates a rectangular loop route: origin → A → B → C → origin,
    /// with 90° turns at each corner so outbound and return use different streets.
    @MainActor
    func generateLoopRoute(
        targetMiles: Double,
        from origin: CLLocationCoordinate2D
    ) async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        // Each of the 4 sides is ~targetMiles/4 of road distance.
        // Straight-line factor 0.8 accounts for road winding.
        let legStraightLine = targetMiles * 0.8 / 4.0

        var bestLegs: [MKRoute]?
        var bestBearing: Double?
        var bestDelta = Double.infinity

        // Snap to cardinal directions so legs follow the street grid (no diagonals).
        let cardinals: [Double] = [0, 90, 180, 270]
        for bearing in cardinals.shuffled() {

            // Four corners of a rectangle, each 90° turn from the last.
            let pointA = destinationCoordinate(from: origin, bearing: bearing,
                                               distanceMiles: legStraightLine)
            let pointB = destinationCoordinate(from: pointA, bearing: bearing + 90,
                                               distanceMiles: legStraightLine)
            let pointC = destinationCoordinate(from: pointB, bearing: bearing + 180,
                                               distanceMiles: legStraightLine)
            // pointC + 270° closes back to origin.

            async let r1 = requestWalkingRoute(from: origin, to: pointA)
            async let r2 = requestWalkingRoute(from: pointA, to: pointB)
            async let r3 = requestWalkingRoute(from: pointB, to: pointC)
            async let r4 = requestWalkingRoute(from: pointC, to: origin)

            guard let leg1 = try? await r1,
                  let leg2 = try? await r2,
                  let leg3 = try? await r3,
                  let leg4 = try? await r4 else { continue }

            // Reject any leg deviating >25° from its expected cardinal — tighter
            // than before to eliminate off-grid shortcuts and diagonal roads.
            let expectedBearings = [bearing, bearing + 90, bearing + 180, bearing + 270]
            let legs = [leg1, leg2, leg3, leg4]
            guard zip(legs, expectedBearings).allSatisfy({ isLegAligned($0.0, expectedBearing: $0.1) }) else { continue }

            // Reject lopsided rectangles: opposite legs (1↔3 and 2↔4) must be
            // within 35% of each other in distance, keeping the shape square.
            let ratio13 = min(leg1.distance, leg3.distance) / max(leg1.distance, leg3.distance)
            let ratio24 = min(leg2.distance, leg4.distance) / max(leg2.distance, leg4.distance)
            guard ratio13 >= 0.65, ratio24 >= 0.65 else { continue }

            let totalMiles = (leg1.distance + leg2.distance + leg3.distance + leg4.distance) / 1609.34
            let delta = abs(totalMiles - targetMiles)
            if delta < bestDelta {
                bestLegs = [leg1, leg2, leg3, leg4]
                bestBearing = bearing
                bestDelta = delta
            }
            if delta / targetMiles < 0.15 { break }
        }

        if let legs = bestLegs {
            route = legs[0]
            loopRemainingLegs = Array(legs.dropFirst())
            lastBearing = bestBearing
            destination = origin
        } else if route == nil {
            errorMessage = "Could not generate a loop route here. Try a different distance."
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
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
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

    /// Returns true if the leg is "clean": follows the grid and doesn't meander.
    private func isLegAligned(_ route: MKRoute, expectedBearing: Double) -> Bool {
        let coords = route.polyline.coordinates
        guard let first = coords.first, let last = coords.last else { return true }

        let dLon = (last.longitude - first.longitude) * .pi / 180
        let lat1 = first.latitude * .pi / 180
        let lat2 = last.latitude * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let netBearing = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)

        let expected = (expectedBearing + 360).truncatingRemainder(dividingBy: 360)
        var diff = abs(netBearing - expected)
        if diff > 180 { diff = 360 - diff }
        guard diff < 25 else { return false }

        let directDistance = MKMapPoint(first).distance(to: MKMapPoint(last))
        guard route.distance > 0, (directDistance / route.distance) >= 0.65 else { return false }

        return true
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
