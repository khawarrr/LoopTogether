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

extension MKPolyline {
    /// Compass heading (degrees) over the first `span` meters of the line —
    /// which way it heads as it leaves its start.
    func headingAtStart(over span: CLLocationDistance = 20) -> Double? {
        Self.heading(along: coordinates, over: span)
    }

    /// Compass heading (degrees) over the last `span` meters of the line —
    /// which way it's heading as it reaches its end.
    func headingAtEnd(over span: CLLocationDistance = 20) -> Double? {
        Self.heading(along: coordinates.reversed(), over: span).map { ($0 + 180).truncatingRemainder(dividingBy: 360) }
    }

    private static func heading(along coords: [CLLocationCoordinate2D], over span: CLLocationDistance) -> Double? {
        guard let first = coords.first else { return nil }
        // Measure to the first point at least `span` away (or the farthest
        // available) so tiny segments at a snapped waypoint don't skew it.
        guard let target = coords.first(where: { $0.distance(to: first) >= span })
                ?? coords.last, target.distance(to: first) > 1 else { return nil }
        return first.bearing(to: target)
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

    /// Initial compass bearing (degrees, 0 = north) from this coordinate to another.
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
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

    /// Route polyline and the distance along the route at each vertex,
    /// computed once rather than on every GPS update.
    private let coords: [CLLocationCoordinate2D]
    private let cumulative: [CLLocationDistance]

    /// Index of the polyline segment containing `traveledDistance`.
    private var segmentIndex = 0

    /// Location at the previous update, used to bound how far progress can
    /// plausibly advance between two fixes.
    private var lastLocation: CLLocation?

    /// A match farther ahead than the user could have moved is only accepted
    /// once consecutive fixes agree on it (e.g. rejoining after a shortcut),
    /// so a single GPS outlier can't jump progress to a later pass.
    private var pendingJump: CLLocationDistance?
    private var pendingJumpCount = 0
    private static let jumpConfirmations = 3

    /// How far (meters) the user can be from the route line and still count
    /// as on it — covers GPS error plus running on the sidewalk rather than
    /// the road centerline the polyline follows.
    private static let onRouteTolerance: CLLocationDistance = 40

    /// When the user is off the route, how far ahead (meters along the
    /// route) we'll look for the closest point to keep progress moving.
    private static let offRouteLookahead: CLLocationDistance = 250

    /// How far behind current progress (meters along the route) matching
    /// starts, so a fix that lands slightly behind us still matches this
    /// pass instead of skipping ahead to a later one.
    private static let matchBacktrack: CLLocationDistance = 50

    /// Meters remaining until the end of the current step (i.e., the next turn).
    var distanceToNextTurn: CLLocationDistance = 0

    /// Meters remaining until the end of the route.
    var remainingDistance: CLLocationDistance {
        max(0, route.distance - traveledDistance)
    }

    /// The instruction for the upcoming maneuver. Each MapKit step's polyline
    /// leads up to its maneuver (step 1 is "the street you're on, then take a
    /// right onto X"), so the maneuver ahead is the current step's own.
    var upcomingInstruction: String {
        guard route.steps.indices.contains(currentStepIndex) else { return "Arriving at finish" }
        return route.steps[currentStepIndex].instructions
    }

    /// True once the user is on the leg's final step, i.e. the next maneuver
    /// is arriving at the leg's end.
    var isOnFinalStep: Bool {
        currentStepIndex >= route.steps.count - 1
    }

    /// Whether the user has effectively reached the end of the route.
    var hasArrived: Bool {
        remainingDistance < 20  // meters
    }

    init(route: MKRoute) {
        self.route = route
        let coords = route.polyline.coordinates
        var cumulative: [CLLocationDistance] = coords.isEmpty ? [] : [0]
        for i in coords.indices.dropFirst() {
            cumulative.append(cumulative[i - 1] + coords[i - 1].distance(to: coords[i]))
        }
        self.coords = coords
        self.cumulative = cumulative
    }

    // MARK: Update

    /// Recomputes progress given the user's latest location by matching it
    /// to a point on the route polyline and measuring the distance along the
    /// route to that point.
    ///
    /// Routes can pass the same spot more than once (out and back along one
    /// street, or doubling back to reach a waypoint across the road). Matching
    /// to the closest point anywhere would let one noisy fix snap progress to
    /// the later pass, and since progress never goes backwards the user would
    /// be stuck "ahead". So we walk forward from the current position and take
    /// the first stretch of route within `onRouteTolerance` of the user. Where
    /// that stretch covers both sides of a tight U-turn, we prefer the point
    /// the user could actually have reached since the last fix. Only if the
    /// user is off the route entirely do we fall back to the closest point
    /// within a short lookahead window.
    mutating func update(userLocation: CLLocation) {
        guard coords.count > 1 else { return }

        // Farthest along the route the user could plausibly be now: allow
        // twice the straight-line distance moved, plus slack for GPS error.
        let moved = lastLocation.map { userLocation.distance(from: $0) } ?? .infinity
        let reach = traveledDistance + 50 + 2 * moved
        lastLocation = userLocation

        typealias Match = (distance: CLLocationDistance, traveled: CLLocationDistance, segment: Int)
        var onRoute: Match?
        var onRouteInReach: Match?
        var nearestAhead: Match?

        var start = segmentIndex
        while start > 0, cumulative[start] > traveledDistance - Self.matchBacktrack {
            start -= 1
        }

        for i in start..<(coords.count - 1) {
            let (closest, t) = Self.closestPointOnSegment(
                point: userLocation.coordinate,
                segmentStart: coords[i],
                segmentEnd: coords[i + 1]
            )
            let distance = userLocation.distance(to: closest)
            let match: Match = (distance, cumulative[i] + (cumulative[i + 1] - cumulative[i]) * t, i)

            if distance <= Self.onRouteTolerance {
                if distance < onRoute?.distance ?? .infinity {
                    onRoute = match
                }
                if match.traveled <= reach, distance < onRouteInReach?.distance ?? .infinity {
                    onRouteInReach = match
                }
            } else if onRoute != nil {
                // Left the first nearby stretch — any later match is a
                // different pass over the same area.
                break
            }

            if cumulative[i] <= traveledDistance + Self.offRouteLookahead,
               distance < nearestAhead?.distance ?? .infinity {
                nearestAhead = match
            }
        }

        guard let best = onRouteInReach ?? onRoute ?? nearestAhead else { return }

        if best.traveled > reach {
            if let pending = pendingJump, abs(best.traveled - pending) < 100 {
                pendingJumpCount += 1
            } else {
                pendingJumpCount = 1
            }
            pendingJump = best.traveled
            guard pendingJumpCount >= Self.jumpConfirmations else { return }
        }
        pendingJump = nil
        pendingJumpCount = 0

        // Never allow progress to go backwards (GPS jitter guard)
        if best.traveled > traveledDistance {
            traveledDistance = best.traveled
            segmentIndex = best.segment
        }

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
