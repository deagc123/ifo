//
//  InstalledAppsView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct InstalledAppsView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("Info") {
                Text("Only apps with schemes declared in Info.plist can be detected (max 50); tap an installed app to open it.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Common Apps") {
                ForEach(manager.installedApps) { app in
                    HStack {
                        Image(systemName: app.iconName)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.scheme)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(app.isInstalled ? String(localized: "Installed") : String(localized: "Not Installed"))
                            .font(.footnote)
                            .foregroundColor(app.isInstalled ? .green : .gray)
                        Button(String(localized: "Open")) {
                            manager.openApp(app)
                        }
                        .disabled(!app.isInstalled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Installed Apps")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    InstalledAppsView()
}
