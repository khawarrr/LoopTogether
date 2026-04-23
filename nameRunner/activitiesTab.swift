//
//  ActivitiesTab.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI
internal import HealthKit
import FirebaseAuth
internal import MapKit

struct ActivitiesTab: View {
    @Environment(RunStore.self) private var runStore
    @Environment(AuthManager.self) private var authManager

    @State private var showNewRun = false
    @State private var showActiveRunDetail = false
    @State private var showAuth = false
    @State private var stepManager = StepCountManager()

    private let historyPreviewCount = 3

    var body: some View {
        NavigationStack {
            List {
                activeRunSection
                stepsSection
                dailyChallengesSection
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
    private var stepsSection: some View {
        Section("Steps Today") {
            StepsTodayCard(manager: stepManager)
        }
        .onAppear {
            Task {
                await stepManager.requestAuthAndLoad()
                if let uid = authManager.currentUser?.uid, stepManager.stepsToday > 0 {
                    try? await FriendsService.syncDailySteps(uid: uid, steps: stepManager.stepsToday)
                }
            }
        }
        .onChange(of: stepManager.stepsToday) { _, steps in
            guard steps > 0, let uid = authManager.currentUser?.uid else { return }
            Task { try? await FriendsService.syncDailySteps(uid: uid, steps: steps) }
        }
    }

    private var todayRuns: [CompletedRun] {
        runStore.history.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var dailyChallengesSection: some View {
        DailyChallengesSection(stepsToday: stepManager.stepsToday, todayRuns: todayRuns)
    }

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
                .onDelete { indexSet in
                    for index in indexSet {
                        runStore.deleteRun(id: runStore.history[index].id)
                    }
                }
            }
        } header: {
            HStack {
                Text("Runs History")
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

// MARK: - Steps today card

struct StepsTodayCard: View {
    let manager: StepCountManager

    private let goal = 10_000
    private var progress: Double { min(Double(manager.stepsToday) / Double(goal), 1.0) }
    private var progressColor: Color {
        switch progress {
        case ..<0.4: return .orange
        case ..<0.8: return .blue
        default: return .green
        }
    }

    var body: some View {
        if !StepCountManager.isHealthAvailable {
            Label("Health not available on this device.", systemImage: "heart.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 7)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: progress)
                    if manager.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "shoeprints.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(progressColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(manager.isLoading ? "—" : "\(manager.stepsToday.formatted()) steps")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("Goal: \(goal.formatted()) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !manager.isLoading && manager.stepsToday >= goal {
                        Text("Goal reached!")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(progressColor)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
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
    @Environment(AppSettings.self) private var settings

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            RunThumbnailView(run: run)

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
                Text(settings.formatDistance(run.distanceMeters))
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
        settings.formatPace(pace)
    }
}

// MARK: - Run thumbnail

private struct RunThumbnailView: View {
    let run: CompletedRun

    private var coords: [CLLocationCoordinate2D] { run.displayCoordinates }

    private var mapPosition: MapCameraPosition {
        guard coords.count > 1 else { return .automatic }
        let poly = MKPolyline(coordinates: coords, count: coords.count)
        let rect = poly.boundingMapRect
        let padded = rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2)
        return .region(MKCoordinateRegion(padded))
    }

    var body: some View {
        if coords.count > 1 {
            Map(initialPosition: mapPosition, interactionModes: []) {
                MapPolyline(coordinates: coords)
                    .stroke(.blue, lineWidth: 2)
                if let first = coords.first {
                    Annotation("", coordinate: first) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                }
                if let last = coords.last {
                    Annotation("", coordinate: last) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .allowsHitTesting(false)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 52, height: 52)
                Image(systemName: run.isWalk ? "figure.walk" : run.isFreeRun ? "figure.run" : "map.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
    }
}

#Preview {
    let auth = AuthManager()
    ActivitiesTab()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
