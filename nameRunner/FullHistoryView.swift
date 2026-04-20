//
//  FullHistoryView.swift
//  nameRunner
//
//  Created by Khawar Khan on 4/19/26.
//

import SwiftUI

/// Shows the full list of completed runs, pushed from the Activities tab
/// when there are more runs than fit in the preview.
struct FullHistoryView: View {
    @Environment(RunStore.self) private var runStore

    var body: some View {
        List {
            ForEach(runStore.history) { run in
                NavigationLink {
                    RunDetailView(run: run)
                } label: {
                    HistoryRunRow(run: run)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let auth = AuthManager()
    NavigationStack {
        FullHistoryView()
            .environment(RunStore(authManager: auth))
            .environment(auth)
    }
}
