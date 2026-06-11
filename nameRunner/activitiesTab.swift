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

    @Environment(AppSettings.self) private var settings

    @State private var showNewRun = false
    @State private var showBuildRoute = false
    @State private var showActiveRunDetail = false
    @State private var showAuth = false
    @State private var stepManager = StepCountManager()

    private let historyPreviewCount = 3

    var body: some View {
        NavigationStack {
            List {
                activeRunSection
                stepsSection
                monthlyGoalSection
                dailyChallengesSection
                Section("Monthly Activity") {
                    RunCalendarView(history: runStore.history)
                        .listRowInsets(.init())
                        .listRowBackground(Color.clear)
                }
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

                        Button {
                            showBuildRoute = true
                        } label: {
                            Label("Build Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
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
            .sheet(isPresented: $showBuildRoute) {
                BuildRouteView()
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

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    @ViewBuilder
    private var monthlyGoalSection: some View {
        if settings.monthlyGoalMiles > 0 {
            let cal = Calendar.current
            let now = Date()
            let monthMiles = runStore.history
                .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
                .reduce(0) { $0 + $1.distanceMiles }
            let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
            let dayOfMonth = cal.component(.day, from: now)
            let daysRemaining = max(0, daysInMonth - dayOfMonth)
            let monthName = Self.monthFormatter.string(from: now)

            Section {
                MonthlyGoalRingView(
                    goalMiles: settings.monthlyGoalMiles,
                    completedMiles: monthMiles,
                    daysRemaining: daysRemaining,
                    monthName: monthName
                )
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                NavigationLink(destination: MonthlyGoalSettingsView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                .frame(width: 44, height: 44)
                            Image(systemName: "target")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Set a Monthly Goal")
                                .font(.headline)
                            Text("Track your progress toward a distance goal each month.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
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

// MARK: - Monthly Goal Ring

struct MonthlyGoalRingView: View {
    let goalMiles: Double
    let completedMiles: Double
    let daysRemaining: Int
    let monthName: String

    private var progress: Double { min(completedMiles / max(goalMiles, 1), 1.0) }
    private var percent: Int { Int(progress * 100) }

    private var ringColor: Color {
        switch progress {
        case ..<0.4: return .blue
        case ..<0.8: return .orange
        default:     return .green
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("\(monthName.uppercased()) GOAL")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.5)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
                    .frame(width: 160, height: 160)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)

                // Center content
                VStack(spacing: 4) {
                    Text("\(percent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(ringColor)
                        .monospacedDigit()
                    Text("Complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            VStack(spacing: 6) {
                Text(String(format: "%.1f / %.0f miles", completedMiles, goalMiles))
                    .font(.title3.bold())
                    .monospacedDigit()

                HStack(spacing: 4) {
                    if progress >= 1.0 {
                        Label("Goal reached!", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Run Calendar

struct RunCalendarView: View {
    let history: [CompletedRun]
    @Environment(AppSettings.self) private var settings

    @State private var displayedMonth: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    private let cal = Calendar.current
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
    }

    private var firstWeekdayOffset: Int {
        cal.component(.weekday, from: displayedMonth) - 1
    }

    private var milesByDay: [Int: Double] {
        let year  = cal.component(.year,  from: displayedMonth)
        let month = cal.component(.month, from: displayedMonth)
        var result: [Int: Double] = [:]
        for run in history {
            guard cal.component(.year,  from: run.date) == year,
                  cal.component(.month, from: run.date) == month else { continue }
            let day = cal.component(.day, from: run.date)
            result[day, default: 0] += run.distanceMiles
        }
        return result
    }

    private func isToday(_ day: Int) -> Bool {
        let today = cal.dateComponents([.year, .month, .day], from: Date())
        return today.year  == cal.component(.year,  from: displayedMonth) &&
               today.month == cal.component(.month, from: displayedMonth) &&
               today.day   == day
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(monthTitle)
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Day-of-week headers
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    CalendarDayCell(
                        day: day,
                        miles: milesByDay[day],
                        isToday: isToday(day),
                        settings: settings
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct CalendarDayCell: View {
    let day: Int
    let miles: Double?
    let isToday: Bool
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .blue : .primary)

            if let miles {
                Text(String(format: "%.1f", miles))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue, in: Capsule())
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    let auth = AuthManager()
    ActivitiesTab()
        .environment(RunStore(authManager: auth))
        .environment(LocationManager())
        .environment(auth)
}
