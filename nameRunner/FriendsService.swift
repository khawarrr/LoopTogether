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

        let doc = try await ref.getDocument()
        let storedWeekStart = (doc.data()?["weekStart"] as? Timestamp)?.dateValue()
        let currentWeekly = doc.data()?["weeklyMiles"] as? Double ?? 0

        let isNewWeek: Bool
        if let stored = storedWeekStart {
            isNewWeek = stored < weekStart
        } else {
            isNewWeek = true
        }

        let newWeeklyMiles = isNewWeek ? addedMiles : currentWeekly + addedMiles

        try await ref.setData([
            "displayName": displayName,
            "weeklyMiles": newWeeklyMiles,
            "weekStart": Timestamp(date: weekStart),
            "totalMiles": FieldValue.increment(addedMiles),
            "totalRuns": FieldValue.increment(Int64(1))
        ], merge: true)
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
        return UserProfile(
            id: doc.documentID,
            displayName: data["displayName"] as? String ?? "Runner",
            weeklyMiles: data["weeklyMiles"] as? Double ?? 0,
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
