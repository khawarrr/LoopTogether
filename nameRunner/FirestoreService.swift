//
//  FirestoreService.swift
//  nameRunner
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct FirestoreService {
    private static let db = Firestore.firestore()

    static func saveRun(_ run: CompletedRun, for uid: String) async throws {
        var data: [String: Any] = [
            "id": run.id.uuidString,
            "date": Timestamp(date: run.date),
            "durationSeconds": run.durationSeconds,
            "distanceMeters": run.distanceMeters,
            "caloriesBurned": run.caloriesBurned,
            "pathCoordinates": run.pathCoordinates.map { ["lat": $0.latitude, "lng": $0.longitude] }
        ]
        if let planned = run.plannedRouteCoordinates {
            data["plannedRouteCoordinates"] = planned.map { ["lat": $0.latitude, "lng": $0.longitude] }
        }
        if let dest = run.destination {
            data["destination"] = ["lat": dest.latitude, "lng": dest.longitude]
        }
        try await db
            .collection("users").document(uid)
            .collection("runs").document(run.id.uuidString)
            .setData(data)
    }

    static func loadRuns(for uid: String) async throws -> [CompletedRun] {
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("runs")
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap(makeRun)
    }

    private static func makeRun(from doc: QueryDocumentSnapshot) -> CompletedRun? {
        let d = doc.data()
        guard
            let idStr = d["id"] as? String, let id = UUID(uuidString: idStr),
            let ts = d["date"] as? Timestamp,
            let duration = d["durationSeconds"] as? Double,
            let distance = d["distanceMeters"] as? Double,
            let calories = d["caloriesBurned"] as? Double
        else { return nil }

        func coords(_ key: String) -> [CLLocationCoordinate2D] {
            (d[key] as? [[String: Double]] ?? []).compactMap { p in
                guard let lat = p["lat"], let lng = p["lng"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        let planned: [CLLocationCoordinate2D]? = (d["plannedRouteCoordinates"] as? [[String: Double]]).map {
            $0.compactMap { p -> CLLocationCoordinate2D? in
                guard let lat = p["lat"], let lng = p["lng"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        var destination: CLLocationCoordinate2D?
        if let p = d["destination"] as? [String: Double],
           let lat = p["lat"], let lng = p["lng"] {
            destination = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        return CompletedRun(
            id: id,
            date: ts.dateValue(),
            durationSeconds: duration,
            distanceMeters: distance,
            caloriesBurned: calories,
            pathCoordinates: coords("pathCoordinates"),
            plannedRouteCoordinates: planned,
            destination: destination
        )
    }
}
