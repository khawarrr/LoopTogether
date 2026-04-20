//
//  ActivitiesTab.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI

struct ActivitiesTab: View {
    @Environment(RunStore.self) private var runStore
    @Environment(AuthManager.self) private var authManager

    @State private var showNewRun = false
    @State private var showActiveRunDetail = false
    @State private var showAuth = false

    private let historyPreviewCount = 3

    var body: some View {
        NavigationStack {
            List {
                activeRunSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            runStore.startFreeRun()
                        } label: {
                            Label("Free Run", systemImage: "figure.run")
                        }

                        Button {
                            showNewRun = true
                        } label: {
                            Label("Generate Route", systemImage: "map")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(runStore.activeSession != nil)
                }
            }
            .sheet(isPresented: $showNewRun) {
                NewRunView()
            }
            .sheet(isPresented: $showAuth) {
                AuthView()
            }
            .fullScreenCover(isPresented: $showActiveRunDetail) {
                if let session = runStore.activeSession {
                    ActiveRunDetailView(session: session)
                }
            }
            // Auto-open the detail view whenever a new session starts
            .onChange(of: runStore.activeSession?.id) { _, newId in
                if newId != nil {
                    showActiveRunDetail = true
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var activeRunSection: some View {
        if let session = runStore.activeSession {
            Section {
                Button {
                    showActiveRunDetail = true
                } label: {
                    ActiveRunCard(session: session)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Current Run")
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section {
            if !authManager.isSignedIn {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No runs yet",
                        systemImage: "figure.run.circle",
                        description: Text("Tap + to start a free run or generate a route.")
                    )
                    Divider()
                    VStack(spacing: 10) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Sign in to save and view your run history")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Sign In / Sign Up") {
                            showAuth = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
            } else if runStore.isLoadingHistory {
                HStack {
                    Spacer()
                    ProgressView("Loading history…")
                    Spacer()
                }
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else if runStore.history.isEmpty {
                ContentUnavailableView(
                    "No runs yet",
                    systemImage: "figure.run.circle",
                    description: Text("Tap + to start a free run or generate a route.")
                )
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(runStore.history.prefix(historyPreviewCount)) { run in
                    NavigationLink {
                        RunDetailView(run: run)
                    } label: {
                        HistoryRunRow(run: run)
                    }
                }
            }
        } header: {
            HStack {
                Text("History")
                Spacer()
                if authManager.isSignedIn, runStore.history.count > historyPreviewCount {
                    NavigationLink {
                        FullHistoryView()
                    } label: {
                        Text("See all (\(runStore.history.count))")
                            .textCase(.none)
                            .font(.footnote)
                    }
                }
            }
        }
    }
}

// MARK: - Active run card

struct ActiveRunCard: View {
    let session: RunSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.isFreeRun ? "Free Run" : "Active Run")
                    .font(.headline)

                // TimelineView re-renders every second to keep the clock live.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Self.timeString(session.elapsedTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                StatusDot(isPaused: session.isPaused)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(String(format: "%.2f mi", session.distanceCoveredMiles))
                        .font(.caption.bold())
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    static func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

/// Green pulsing dot if running; solid orange if paused.
struct StatusDot: View {
    let isPaused: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isPaused ? Color.orange : Color.green)
            .frame(width: 10, height: 10)
            .scaleEffect(pulse && !isPaused ? 1.35 : 1.0)
            .opacity(pulse && !isPaused ? 0.6 : 1.0)
            .animation(
                isPaused
                    ? .default
                    : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear {
                if !isPaused { pulse = true }
            }
            .onChange(of: isPaused) { _, newValue in
                pulse = !newValue
            }
    }
}

// MARK: - History row

struct HistoryRunRow: View {
    let run: CompletedRun

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 52, height: 52)
                Image(systemName: run.isFreeRun ? "figure.run" : "map.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: run.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if run.isFreeRun {
                        Text("· Free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(String(format: "%.2f mi", run.distanceMiles))
                    .font(.headline)
                    .monospacedDigit()

                HStack(spacing: 10) {
                    Label(ActiveRunCard.timeString(run.durationSeconds), systemImage: "clock")
                    if let pace = run.averagePaceMinutesPerMile {
                        Label(paceString(pace), systemImage: "bolt.fill")
                    }
                    Label(String(format: "%.0f cal", run.caloriesBurned), systemImage: "flame.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func paceString(_ pace: Double) -> String {
        let m = Int(pace)
        let s = Int((pace - Double(m)) * 60)
        return String(format: "%d:%02d/mi", m, s)
    }
}

#Preview {
    let auth = AuthManager()
    ActivitiesTab()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
