//
//  LocationHelpers.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import Foundation
import CoreLocation
internal import MapKit

// MARK: - MKPolyline convenience

extension MKPolyline {
    /// All coordinates in the polyline as an array.
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: CLLocationCoordinate2D(),
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Distance helpers

extension CLLocationCoordinate2D {
    /// Distance (meters) between two coordinates.
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b)
    }
}

extension CLLocation {
    /// Distance (meters) from this location to a coordinate.
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

// MARK: - Route progress tracking

/// Tracks how far along an MKRoute the user has traveled, and which
/// step (maneuver segment) they are currently on.
struct RouteProgress {
    let route: MKRoute

    /// Index of the step the user is currently walking.
    var currentStepIndex: Int = 0

    /// Total distance (meters) the user has covered along the route.
    private(set) var traveledDistance: CLLocationDistance = 0

    /// Meters remaining until the end of the current step (i.e., the next turn).
    var distanceToNextTurn: CLLocationDistance = 0

    /// Meters remaining until the end of the route.
    var remainingDistance: CLLocationDistance {
        max(0, route.distance - traveledDistance)
    }

    /// The instruction for the upcoming maneuver (next step).
    /// If the user is on the last step, returns an "arriving" message.
    var upcomingInstruction: String {
        let nextIndex = currentStepIndex + 1
        if nextIndex < route.steps.count {
            return route.steps[nextIndex].instructions
        }
        return "Arriving at finish"
    }

    /// Whether the user has effectively reached the end of the route.
    var hasArrived: Bool {
        remainingDistance < 20  // meters
    }

    // MARK: Update

    /// Recomputes progress given the user's latest location by finding the
    /// closest point on the route polyline and measuring cumulative distance
    /// from the start of the route to that point.
    mutating func update(userLocation: CLLocation) {
        let coords = route.polyline.coordinates
        guard coords.count > 1 else { return }

        var bestOffRouteDistance = Double.infinity
        var bestTraveled: CLLocationDistance = 0
        var cumulative: CLLocationDistance = 0

        for i in 0..<(coords.count - 1) {
            let a = coords[i]
            let b = coords[i + 1]
            let (closest, t) = Self.closestPointOnSegment(
                point: userLocation.coordinate,
                segmentStart: a,
                segmentEnd: b
            )
            let segmentLength = a.distance(to: b)
            let distToClosest = userLocation.distance(to: closest)

            if distToClosest < bestOffRouteDistance {
                bestOffRouteDistance = distToClosest
                bestTraveled = cumulative + segmentLength * t
            }
            cumulative += segmentLength
        }

        // Never allow progress to go backwards (GPS jitter guard)
        traveledDistance = max(traveledDistance, bestTraveled)

        // Figure out which step we're on by walking through cumulative step distances.
        var stepEnd: CLLocationDistance = 0
        for (i, step) in route.steps.enumerated() {
            stepEnd += step.distance
            if traveledDistance < stepEnd {
                currentStepIndex = max(currentStepIndex, i)
                distanceToNextTurn = stepEnd - traveledDistance
                return
            }
        }

        // Past all steps
        currentStepIndex = max(0, route.steps.count - 1)
        distanceToNextTurn = 0
    }

    /// Closest point on a geographic segment to a given coordinate, computed
    /// in Mercator map-point space (accurate enough for urban-scale segments).
    /// Returns the closest point and the parameter t in [0, 1] along the segment.
    private static func closestPointOnSegment(
        point: CLLocationCoordinate2D,
        segmentStart: CLLocationCoordinate2D,
        segmentEnd: CLLocationCoordinate2D
    ) -> (coordinate: CLLocationCoordinate2D, t: Double) {
        let p = MKMapPoint(point)
        let a = MKMapPoint(segmentStart)
        let b = MKMapPoint(segmentEnd)

        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSquared = dx * dx + dy * dy

        guard lenSquared > 0 else { return (segmentStart, 0) }

        let rawT = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSquared
        let t = min(max(rawT, 0), 1)
        let closest = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
        return (closest.coordinate, t)
    }
}
