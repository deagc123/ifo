//
//  BundleInfoView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct BundleInfoView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("App Info") {
                InfoRow(label: "Version", value: manager.bundleInfo.version)
                InfoRow(label: "Build", value: manager.bundleInfo.build)
                InfoRow(label: "Bundle ID", value: manager.bundleInfo.bundleIdentifier)
                InfoRow(label: "Display Name", value: manager.bundleInfo.displayName)
                InfoRow(label: "Bundle Name", value: manager.bundleInfo.bundleName)
                InfoRow(label: "Executable", value: manager.bundleInfo.executable)
                InfoRow(label: "Minimum OS", value: manager.bundleInfo.minimumOSVersion)
                InfoRow(label: "SDK Name", value: manager.bundleInfo.sdkName)
                InfoRow(label: "Launch Arguments", value: manager.environmentInfo.launchArguments.isEmpty ? String(localized: "None") : manager.environmentInfo.launchArguments)
            }

            Section("Runtime Status") {
                InfoRow(label: "App State", value: manager.bundleInfo.applicationState)
                InfoRow(label: "Background Time Left", value: backgroundTimeText)
                InfoRow(label: "Background Refresh", value: manager.environmentInfo.backgroundRefreshStatus)
                InfoRow(label: "Notification Permission", value: manager.notificationAuthStatus)
                InfoRow(label: "Multiple Scenes", value: manager.environmentInfo.supportsMultipleScenes ? String(localized: "Supported") : String(localized: "Not Supported"))
                InfoRow(label: "Keep Screen Awake", value: manager.environmentInfo.isIdleTimerDisabled ? String(localized: "Yes") : String(localized: "No"))
            }

            Section("Advertising & Push") {
                InfoRow(label: "IDFA", value: manager.idfa)
                InfoRow(label: "Tracking Authorization", value: manager.idfaAuthStatus)
                InfoRow(label: "Push Status", value: manager.pushStatus)
                InfoRow(label: "DeviceToken", value: manager.pushToken)
            }

            Section("Sandbox Paths") {
                InfoRow(label: "Home", value: manager.bundleInfo.homeDirectory)
                InfoRow(label: "Documents", value: manager.bundleInfo.documentsDirectory)
                InfoRow(label: "Caches", value: manager.bundleInfo.cachesDirectory)
                InfoRow(label: "Tmp", value: manager.bundleInfo.tmpDirectory)
            }
        }
        .navigationTitle("Current App")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private var backgroundTimeText: String {
        let remaining = manager.bundleInfo.backgroundTimeRemaining
        guard remaining.isFinite, remaining >= 0, remaining < Double(Int.max) else {
            return String(localized: "Foreground, unlimited")
        }
        return String(localized: "\(Int(remaining)) sec")
    }
}

#Preview {
    BundleInfoView()
}
