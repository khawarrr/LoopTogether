//
//  ProfileTab.swift
//  nameRunner
//

import SwiftUI
import FirebaseAuth

struct ProfileTab: View {
    @Environment(RunStore.self) private var runStore
    @Environment(AuthManager.self) private var authManager
    @Environment(ProfileImageManager.self) private var imageManager

    @State private var showAuth = false
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    private var totalMiles: Double {
        runStore.history.reduce(0) { $0 + $1.distanceMiles }
    }
    private var totalRuns: Int { runStore.history.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if authManager.isSignedIn {
                        signedInHeader
                    } else {
                        guestHeader
                    }
                }

                if authManager.isSignedIn {
                    Section("Account") {
                        Button {
                            showEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "person.crop.circle.badge.plus")
                                .foregroundStyle(.primary)
                        }
                            }
                }

                Section("Settings") {
                    NavigationLink {
                        PlaceholderSettings(title: "Units")
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                    NavigationLink {
                        PlaceholderSettings(title: "Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    NavigationLink {
                        PlaceholderSettings(title: "Voice Guidance")
                    } label: {
                        Label("Voice Guidance", systemImage: "speaker.wave.2")
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                }

                if authManager.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            try? authManager.signOut()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                Spacer()
                            }
                        }
                    }

                    Section {
                        if let error = deleteError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                if isDeletingAccount {
                                    ProgressView()
                                } else {
                                    Text("Delete Account")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isDeletingAccount)
                    } footer: {
                        Text("Permanently deletes your account and all run history.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .sheet(isPresented: $showAuth) {
                AuthView()
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        deleteError = nil
                        do {
                            runStore.clearHistory()
                            try await authManager.deleteAccount()
                        } catch {
                            deleteError = error.localizedDescription
                            isDeletingAccount = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all your run history. This cannot be undone.")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
    }

    // MARK: - Header variants

    private var signedInHeader: some View {
        HStack(spacing: 14) {
            Group {
                if let img = imageManager.profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.blue)
                        .padding(10)
                        .background(Color.blue.opacity(0.15), in: Circle())
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.displayName?.isEmpty == false ? authManager.displayName! : "Set your name")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(authManager.displayName?.isEmpty == false ? .primary : .secondary)
                Text("\(totalRuns) runs · \(String(format: "%.1f", totalMiles)) mi total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var guestHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            Text("Not signed in")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Sign in to save your runs and track progress across devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In / Sign Up") {
                showAuth = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct PlaceholderSettings: View {
    let title: String
    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("Coming soon.")
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let auth = AuthManager()
    ProfileTab()
        .environment(RunStore(authManager: auth))
        .environment(auth)
        .environment(ProfileImageManager())
}
