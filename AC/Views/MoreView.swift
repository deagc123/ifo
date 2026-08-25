//
//  MoreView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    InstalledAppsView()
                } label: {
                    Label(String(localized: "Installed Apps"), systemImage: "square.grid.2x2")
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label(String(localized: "About"), systemImage: "info.circle")
                }
            }
        }
        .navigationTitle(String(localized: "More"))
        .listStyle(InsetGroupedListStyle())
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}
