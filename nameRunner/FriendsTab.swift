//
//  FriendsTab.swift
//  nameRunner
//

import SwiftUI
import FirebaseAuth

struct FriendsTab: View {
    @Environment(AuthManager.self) private var authManager
    @State private var friendsManager = FriendsManager()
    @State private var showAddFriend = false
    @State private var selectedPeriod: LeaderboardPeriod = .daily

    enum LeaderboardPeriod { case daily, weekly }

    var body: some View {
        NavigationStack {
            Group {
                if authManager.isSignedIn {
                    signedInContent
                } else {
                    guestContent
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                if authManager.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddFriend = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                if let uid = authManager.currentUser?.uid,
                   let name = authManager.displayName {
                    AddFriendView(
                        myUID: uid,
                        myName: name,
                        friendsManager: friendsManager
                    )
                }
            }
            .onAppear {
                guard let uid = authManager.currentUser?.uid,
                      let name = authManager.displayName ?? authManager.currentUser?.email else { return }
                Task { await friendsManager.load(uid: uid, myName: name) }
            }
        }
    }

    // MARK: - Signed-in content

    private var signedInContent: some View {
        List {
            if !friendsManager.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(friendsManager.pendingRequests) { request in
                        FriendRequestRow(
                            request: request,
                            onAccept: {
                                guard let uid = authManager.currentUser?.uid,
                                      let name = authManager.displayName ?? authManager.currentUser?.email else { return }
                                Task {
                                    try? await friendsManager.accept(uid: uid, myName: name, request: request)
                                    await friendsManager.load(uid: uid, myName: name)
                                }
                            },
                            onDecline: {
                                guard let uid = authManager.currentUser?.uid else { return }
                                Task { try? await friendsManager.decline(uid: uid, request: request) }
                            }
                        )
                    }
                }
            }

            Section {
                Picker("Period", selection: $selectedPeriod) {
                    Text("Daily").tag(LeaderboardPeriod.daily)
                    Text("Weekly").tag(LeaderboardPeriod.weekly)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                let entries = selectedPeriod == .weekly ? friendsManager.weeklyLeaderboard : friendsManager.dailyLeaderboard
                if friendsManager.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if entries.isEmpty {
                    emptyLeaderboard
                } else {
                    ForEach(entries) { entry in
                        LeaderboardRow(entry: entry, period: selectedPeriod)
                            .swipeActions(edge: .trailing) {
                                if !entry.isMe {
                                    Button(role: .destructive) {
                                        guard let uid = authManager.currentUser?.uid else { return }
                                        Task { try? await friendsManager.removeFriend(uid: uid, friendUID: entry.id) }
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                    }
                }
            } header: {
                Text(selectedPeriod == .weekly ? "Weekly Leaderboard" : "Daily Leaderboard")
            }

            if let error = friendsManager.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            guard let uid = authManager.currentUser?.uid,
                  let name = authManager.displayName ?? authManager.currentUser?.email else { return }
            await friendsManager.load(uid: uid, myName: name)
        }
    }

    private var emptyLeaderboard: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No friends yet")
                .font(.headline)
            Text("Tap + to add a friend using their code.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Guest content

    private var guestContent: some View {
        ContentUnavailableView(
            "Sign In to Use Friends",
            systemImage: "person.2.slash",
            description: Text("Create an account to add friends and compare weekly miles.")
        )
    }
}

// MARK: - Leaderboard row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let period: FriendsTab.LeaderboardPeriod
    @Environment(AppSettings.self) private var settings

    private var medal: String? {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let m = medal {
                Text(m).font(.title2)
            } else {
                Text("\(entry.rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.displayName)
                        .font(.body)
                        .fontWeight(entry.isMe ? .semibold : .regular)
                    if entry.isMe {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                if period == .weekly {
                    Text("\(settings.formatMiles(entry.weeklyMiles)) this week")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(settings.formatMiles(entry.dailyMiles)) today")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.dailySteps.formatted())
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("steps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(entry.isMe ? Color.blue.opacity(0.05) : nil)
    }
}

// MARK: - Friend request row

private struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.body)
                Text(request.sentAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Accept") { onAccept() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button("Decline") { onDecline() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
        }
    }
}

// MARK: - Add friend sheet

struct AddFriendView: View {
    let myUID: String
    let myName: String
    let friendsManager: FriendsManager

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isSending = false
    @State private var sentMessage: String?
    @State private var sendError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Friend Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(myUID)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    ShareLink(
                        item: "Use this code to add me on LoopTogether:\n\(myUID)",
                        subject: Text("LoopTogether Friend Code")
                    ) {
                        Label("Share My Code", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("My Code")
                }

                Section {
                    TextField("Paste their code here", text: $code)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let msg = sentMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let err = sendError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        sendRequest()
                    } label: {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView()
                            } else {
                                Text("Send Request")
                            }
                            Spacer()
                        }
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                } header: {
                    Text("Add a Friend")
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func sendRequest() {
        isSending = true
        sentMessage = nil
        sendError = nil
        Task {
            do {
                try await friendsManager.sendRequest(from: myUID, myName: myName, toCode: code)
                sentMessage = "Request sent!"
                code = ""
            } catch {
                sendError = error.localizedDescription
            }
            isSending = false
        }
    }
}
