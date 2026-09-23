//
//  SavedRoutesView.swift
//  nameRunner
//

import SwiftUI

/// Sheet listing the user's saved routes. Tapping one hands it back to
/// `BuildRouteView` to load onto the map; swipe to delete.
struct SavedRoutesView: View {
    let onSelect: (SavedRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(RunStore.self) private var runStore
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Group {
                if runStore.savedRoutes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Routes",
                        systemImage: "bookmark",
                        description: Text("Build a route and tap Save to run it again later.")
                    )
                } else {
                    List {
                        ForEach(runStore.savedRoutes) { route in
                            Button {
                                onSelect(route)
                                dismiss()
                            } label: {
                                row(for: route)
                            }
                            .foregroundStyle(.primary)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { runStore.savedRoutes[$0].id }
                            ids.forEach(runStore.deleteSavedRoute)
                        }
                    }
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func row(for route: SavedRoute) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(settings.formatDistance(route.distanceMeters)) · \(route.waypoints.count) waypoints · \(route.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
