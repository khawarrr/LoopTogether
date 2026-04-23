//
//  UserProfile.swift
//  nameRunner
//

import Foundation

struct UserProfile: Identifiable {
    let id: String          // Firebase UID
    let displayName: String
    let weeklyMiles: Double
    let dailyMiles: Double
    let dailySteps: Int
    let totalMiles: Double
    let totalRuns: Int
}

struct FriendRequest: Identifiable {
    let id: String          // sender UID
    let displayName: String
    let sentAt: Date
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let displayName: String
    let weeklyMiles: Double
    let dailyMiles: Double
    let dailySteps: Int
    let isMe: Bool
    var rank: Int
}
