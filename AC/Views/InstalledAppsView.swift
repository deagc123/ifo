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
            Section("说明") {
                Text("仅能探测 Info.plist 中声明的 scheme（上限 50 个），点击已安装项可唤起对应 App。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("常用 App") {
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
                        Text(app.isInstalled ? "已安装" : "未安装")
                            .font(.footnote)
                            .foregroundColor(app.isInstalled ? .green : .gray)
                        Button("打开") {
                            manager.openApp(app)
                        }
                        .disabled(!app.isInstalled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("已安装 App")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    InstalledAppsView()
}
