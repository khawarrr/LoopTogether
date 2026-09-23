//
//  RootTabView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import _LocationEssentials
internal import MapKit

/// Three-tab shell: Activities, Achievements, Profile.
/// Also acts as the central point that:
///  1. Feeds GPS updates into the active run session — so tracking continues
///     regardless of which tab is visible.
///  2. Auto-completes the run when the user arrives at the finish, and
///     shows the celebration sheet.
struct RootTabView: View {
    @Environment(RunStore.self) private var runStore
    @Environment(LocationManager.self) private var locationManager

    @State private var showDetailsAfterCelebration = false

    var body: some View {
        @Bindable var runStore = runStore

        TabView {
            ActivitiesTab()
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }

            FriendsTab()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }

            AchievementsTab()
                .tabItem {
                    Label("Achievements", systemImage: "medal.fill")
                }

            ProfileTab()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        // Central location-update pump. Every GPS update is forwarded to the
        // active session (if any), so breadcrumb tracking is not tied to any
        // particular view being on screen.
        .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
            guard let session = runStore.activeSession,
                  let loc = locationManager.currentLocation else { return }
            session.updateProgress(userLocation: loc)

            // Auto-complete the run when the user reaches the finish.
            // Gated on `hasArrived` to fire exactly once per session.
            if !session.isFreeRun, session.hasArrived {
                runStore.completeActiveRunAtFinish()
            }
        }
        // Celebration sheet — triggered by auto-completion.
        .fullScreenCover(isPresented: $runStore.shouldShowCompletionCelebration) {
            if let run = runStore.lastCompletedRun {
                CompletionCelebrationView(
                    run: run,
                    onViewDetails: {
                        runStore.shouldShowCompletionCelebration = false
                        // Slight delay so the cover dismisses before the
                        // detail nav-push, avoiding stacked-transition flicker.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showDetailsAfterCelebration = true
                        }
                    },
                    onDismiss: {
                        runStore.shouldShowCompletionCelebration = false
                    }
                )
            }
        }
        // Detail view launched from "View Details" in the celebration sheet.
        .sheet(isPresented: $showDetailsAfterCelebration) {
            if let run = runStore.lastCompletedRun {
                NavigationStack {
                    RunDetailView(run: run)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showDetailsAfterCelebration = false
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    let auth = AuthManager()
    RootTabView()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
