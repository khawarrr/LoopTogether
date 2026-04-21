//
//  FriendsManager.swift
//  nameRunner
//

import Foundation

@Observable
final class FriendsManager {
    var leaderboard: [LeaderboardEntry] = []
    var pendingRequests: [FriendRequest] = []
    var isLoading = false
    var errorMessage: String?

    func load(uid: String, myName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let friendIDs   = FriendsService.getFriendIDs(uid: uid)
            async let requests    = FriendsService.getIncomingRequests(uid: uid)
            async let myProfile   = FriendsService.getUserProfile(uid: uid)

            let (ids, reqs, me) = try await (friendIDs, requests, myProfile)
            pendingRequests = reqs

            var profiles = try await FriendsService.getFriendProfiles(uids: ids)
            // Always include self in leaderboard, using local profile if Firestore not yet written
            let selfProfile = me ?? UserProfile(id: uid, displayName: myName, weeklyMiles: 0, totalMiles: 0, totalRuns: 0)
            profiles.append(selfProfile)

            leaderboard = profiles
                .sorted { $0.weeklyMiles > $1.weeklyMiles }
                .enumerated()
                .map { idx, p in
                    LeaderboardEntry(id: p.id, displayName: p.displayName, weeklyMiles: p.weeklyMiles, isMe: p.id == uid, rank: idx + 1)
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(from uid: String, myName: String, toCode code: String) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        try await FriendsService.sendFriendRequest(from: uid, senderName: myName, to: trimmed)
    }

    func accept(uid: String, myName: String, request: FriendRequest) async throws {
        try await FriendsService.acceptFriendRequest(uid: uid, myName: myName, from: request.id, senderName: request.displayName)
        pendingRequests.removeAll { $0.id == request.id }
    }

    func decline(uid: String, request: FriendRequest) async throws {
        try await FriendsService.declineFriendRequest(uid: uid, from: request.id)
        pendingRequests.removeAll { $0.id == request.id }
    }

    func removeFriend(uid: String, friendUID: String) async throws {
        try await FriendsService.removeFriend(uid: uid, friendUID: friendUID)
        leaderboard.removeAll { $0.id == friendUID }
    }
}
