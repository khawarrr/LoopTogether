//
//  FriendsService.swift
//  nameRunner
//

import Foundation
import FirebaseFirestore

struct FriendsService {
    private static let db = Firestore.firestore()

    // MARK: - User profile / weekly stats

    static func ensureProfile(uid: String, displayName: String) async throws {
        let ref = db.collection("users").document(uid)
        // merge: true so we never overwrite existing stats
        try await ref.setData(["displayName": displayName], merge: true)
    }

    static func updateUserStats(uid: String, displayName: String, addedMiles: Double) async throws {
        let ref = db.collection("users").document(uid)
        let weekStart = currentWeekStart()
        let dayStart = currentDayStart()

        let doc = try await ref.getDocument()
        let data = doc.data() ?? [:]

        let storedWeekStart = (data["weekStart"] as? Timestamp)?.dateValue()
        let isNewWeek = storedWeekStart.map { $0 < weekStart } ?? true
        let currentWeekly = data["weeklyMiles"] as? Double ?? 0
        let newWeeklyMiles = isNewWeek ? addedMiles : currentWeekly + addedMiles

        let storedDayStart = (data["dayStart"] as? Timestamp)?.dateValue()
        let isNewDay = storedDayStart.map { $0 < dayStart } ?? true
        let currentDaily = data["dailyMiles"] as? Double ?? 0
        let newDailyMiles = isNewDay ? addedMiles : currentDaily + addedMiles

        try await ref.setData([
            "displayName": displayName,
            "weeklyMiles": newWeeklyMiles,
            "weekStart": Timestamp(date: weekStart),
            "dailyMiles": newDailyMiles,
            "dayStart": Timestamp(date: dayStart),
            "totalMiles": FieldValue.increment(addedMiles),
            "totalRuns": FieldValue.increment(Int64(1))
        ], merge: true)
    }

    static func syncDailySteps(uid: String, steps: Int) async throws {
        try await db.collection("users").document(uid).setData(
            ["dailySteps": steps, "dayKey": currentDayKey()],
            merge: true
        )
    }

    static func getUserProfile(uid: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return makeProfile(from: doc)
    }

    static func getFriendProfiles(uids: [String]) async throws -> [UserProfile] {
        var profiles: [UserProfile] = []
        for uid in uids {
            if let p = try await getUserProfile(uid: uid) {
                profiles.append(p)
            }
        }
        return profiles
    }

    private static func makeProfile(from doc: DocumentSnapshot) -> UserProfile? {
        guard doc.exists, let data = doc.data() else { return nil }

        // Use a plain date string for day comparison — avoids timezone mismatch
        // when friends are in different time zones.
        let todayKey = currentDayKey()
        let storedDayKey = data["dayKey"] as? String

        // Fall back to legacy timestamp comparison for profiles not yet migrated.
        let isToday: Bool
        if let storedDayKey {
            isToday = storedDayKey == todayKey
        } else {
            let storedDay = (data["dayStart"] as? Timestamp)?.dateValue()
            isToday = storedDay.map { Calendar.current.isDate($0, inSameDayAs: currentDayStart()) } ?? false
        }

        return UserProfile(
            id: doc.documentID,
            displayName: data["displayName"] as? String ?? "Runner",
            weeklyMiles: data["weeklyMiles"] as? Double ?? 0,
            dailyMiles: isToday ? (data["dailyMiles"] as? Double ?? 0) : 0,
            dailySteps: isToday ? (data["dailySteps"] as? Int ?? 0) : 0,
            totalMiles: data["totalMiles"] as? Double ?? 0,
            totalRuns: data["totalRuns"] as? Int ?? 0
        )
    }

    // MARK: - Friends

    static func getFriendIDs(uid: String) async throws -> [String] {
        let snap = try await db.collection("userFriends").document(uid)
            .collection("friends").getDocuments()
        return snap.documents.map { $0.documentID }
    }

    static func sendFriendRequest(from senderUID: String, senderName: String, to targetUID: String) async throws {
        guard senderUID != targetUID else { throw FriendsError.cannotAddSelf }

        let targetDoc = try await db.collection("users").document(targetUID).getDocument()
        guard targetDoc.exists else { throw FriendsError.userNotFound }

        let alreadyFriend = try await db.collection("userFriends").document(targetUID)
            .collection("friends").document(senderUID).getDocument()
        if alreadyFriend.exists { throw FriendsError.alreadyFriends }

        try await db.collection("friendRequests").document(targetUID)
            .collection("incoming").document(senderUID)
            .setData([
                "fromUid": senderUID,
                "fromName": senderName,
                "sentAt": Timestamp(date: Date())
            ])
    }

    static func getIncomingRequests(uid: String) async throws -> [FriendRequest] {
        let snap = try await db.collection("friendRequests").document(uid)
            .collection("incoming").getDocuments()
        return snap.documents.compactMap { doc -> FriendRequest? in
            let d = doc.data()
            guard let name = d["fromName"] as? String,
                  let ts = d["sentAt"] as? Timestamp else { return nil }
            return FriendRequest(id: doc.documentID, displayName: name, sentAt: ts.dateValue())
        }
    }

    static func acceptFriendRequest(uid: String, myName: String, from senderUID: String, senderName: String) async throws {
        let batch = db.batch()
        let now = Timestamp(date: Date())
        batch.setData(
            ["displayName": senderName, "addedAt": now],
            forDocument: db.collection("userFriends").document(uid).collection("friends").document(senderUID)
        )
        batch.setData(
            ["displayName": myName, "addedAt": now],
            forDocument: db.collection("userFriends").document(senderUID).collection("friends").document(uid)
        )
        batch.deleteDocument(
            db.collection("friendRequests").document(uid).collection("incoming").document(senderUID)
        )
        try await batch.commit()
    }

    static func declineFriendRequest(uid: String, from senderUID: String) async throws {
        try await db.collection("friendRequests").document(uid)
            .collection("incoming").document(senderUID).delete()
    }

    static func removeFriend(uid: String, friendUID: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(db.collection("userFriends").document(uid).collection("friends").document(friendUID))
        batch.deleteDocument(db.collection("userFriends").document(friendUID).collection("friends").document(uid))
        try await batch.commit()
    }

    // MARK: - Helpers

    static func currentWeekStart() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    static func currentDayStart() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    static func currentDayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}

enum FriendsError: LocalizedError {
    case userNotFound, alreadyFriends, cannotAddSelf
    var errorDescription: String? {
        switch self {
        case .userNotFound:   return "No user found with that code. Double-check it and try again."
        case .alreadyFriends: return "You're already friends with this person."
        case .cannotAddSelf:  return "You can't add yourself."
        }
    }
}
