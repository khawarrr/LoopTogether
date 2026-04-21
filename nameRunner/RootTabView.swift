//
//  RootTabView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
import AVFoundation
internal import _LocationEssentials
internal import MapKit

/// Three-tab shell: Activities, Achievements, Profile.
/// Also acts as the central point that:
///  1. Feeds GPS updates into the active run session — so tracking continues
///     regardless of which tab is visible.
///  2. Auto-completes the run when the user arrives at the finish, and
///     shows the celebration sheet.
///  3. Drives voice turn-by-turn announcements for route-based runs, so the
///     user hears directions whether they're looking at the active run
///     detail or the focus navigation view.
struct RootTabView: View {
    @Environment(RunStore.self) private var runStore
    @Environment(LocationManager.self) private var locationManager

    @State private var announcer = SpeechAnnouncer()
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
        .environment(announcer)
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
        // Speak the initial heading when a new route-based run starts.
        .onChange(of: runStore.activeSession?.id) { _, newId in
            guard let session = runStore.activeSession,
                  newId != nil,
                  !session.isFreeRun,
                  let first = session.route?.steps.first?.instructions,
                  !first.isEmpty else { return }
            announcer.announceIfNew(
                key: "initial-\(session.id.uuidString)",
                text: first
            )
        }
        // Speak the upcoming turn as the user approaches it.
        // Arrival is announced once, via the auto-complete flow below.
        .onChange(of: runStore.activeSession?.progress?.distanceToNextTurn) { _, _ in
            guard let session = runStore.activeSession,
                  !session.isFreeRun,
                  !session.isPaused,
                  let progress = session.progress else { return }

            if !progress.hasArrived,
               progress.distanceToNextTurn > 0,
               progress.distanceToNextTurn < 60,
               !progress.upcomingInstruction.isEmpty {
                let key = "step-\(session.id.uuidString)-\(progress.currentStepIndex)"
                announcer.announceIfNew(key: key, text: progress.upcomingInstruction)
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
                .onAppear {
                    // Congratulate the runner out loud if sound is enabled.
                    announcer.announceIfNew(
                        key: "celebration-\(run.id.uuidString)",
                        text: "Great run! Well done!"
                    )
                }
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

// MARK: - Voice announcer

/// Speaks upcoming turn instructions. Deduplicates by a caller-provided key so
/// each announcement fires exactly once per key (even across view transitions).
/// Observable so that views can bind to the mute toggle.
@Observable
final class SpeechAnnouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastKey: String?

    /// When `true`, `announceIfNew` silently records the key (so it won't
    /// replay when unmuted) but doesn't speak. Any in-flight utterance is
    /// also stopped when the user mutes mid-announcement.
    var isMuted: Bool = false {
        didSet {
            if isMuted {
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }

    func announceIfNew(key: String, text: String) {
        guard key != lastKey, !text.isEmpty else { return }
        lastKey = key

        // Still update lastKey when muted, so re-enabling audio doesn't
        // trigger a flood of past turns.
        guard !isMuted else { return }

        // Duck other audio (music/podcasts) so prompts cut through.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .voicePrompt,
            options: [.duckOthers, .mixWithOthers]
        )
        try? session.setActive(true, options: [])

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }
}

#Preview {
    let auth = AuthManager()
    RootTabView()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
