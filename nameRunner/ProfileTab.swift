//
//  ProfileTab.swift
//  nameRunner
//

import SwiftUI
import FirebaseAuth

struct ProfileTab: View {
    @Environment(RunStore.self) private var runStore
    @Environment(AuthManager.self) private var authManager

    @State private var showAuth = false

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
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .sheet(isPresented: $showAuth) {
                AuthView()
            }
        }
    }

    // MARK: - Header variants

    private var signedInHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.currentUser?.email ?? "Runner")
                    .font(.headline)
                    .lineLimit(1)
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
}
