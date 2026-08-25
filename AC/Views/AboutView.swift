//
//  AboutView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    Text("ifo")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Text(String(localized: "Version"))
                            .foregroundColor(.secondary)
                        Text(versionText)
                    }
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }

            Section(String(localized: "App Info")) {
                InfoRow(label: "Build", value: manager.bundleInfo.build)
                InfoRow(label: "Bundle ID", value: manager.bundleInfo.bundleIdentifier)
                InfoRow(label: "Display Name", value: manager.bundleInfo.displayName)
                InfoRow(label: "Bundle Name", value: manager.bundleInfo.bundleName)
                InfoRow(label: "Executable", value: manager.bundleInfo.executable)
                InfoRow(label: "Minimum OS", value: manager.bundleInfo.minimumOSVersion)
                InfoRow(label: "SDK Name", value: manager.bundleInfo.sdkName)
                InfoRow(label: "Launch Arguments", value: manager.environmentInfo.launchArguments.isEmpty ? String(localized: "None") : manager.environmentInfo.launchArguments)
            }

            Section(String(localized: "Runtime Status")) {
                InfoRow(label: "App State", value: manager.bundleInfo.applicationState)
                InfoRow(label: "Background Time Left", value: backgroundTimeText)
                InfoRow(label: "Background Refresh", value: manager.environmentInfo.backgroundRefreshStatus)
                InfoRow(label: "Notification Permission", value: manager.notificationAuthStatus)
                InfoRow(label: "Multiple Scenes", value: manager.environmentInfo.supportsMultipleScenes ? String(localized: "Supported") : String(localized: "Not Supported"))
                InfoRow(label: "Keep Screen Awake", value: manager.environmentInfo.isIdleTimerDisabled ? String(localized: "Yes") : String(localized: "No"))
            }

            Section(String(localized: "Advertising & Push")) {
                InfoRow(label: "IDFA", value: manager.idfa)
                InfoRow(label: "Tracking Authorization", value: manager.idfaAuthStatus)
                InfoRow(label: "Push Status", value: manager.pushStatus)
                InfoRow(label: "DeviceToken", value: manager.pushToken)
            }

            Section(String(localized: "Sandbox Paths")) {
                InfoRow(label: "Home", value: manager.bundleInfo.homeDirectory)
                InfoRow(label: "Documents", value: manager.bundleInfo.documentsDirectory)
                InfoRow(label: "Caches", value: manager.bundleInfo.cachesDirectory)
                InfoRow(label: "Tmp", value: manager.bundleInfo.tmpDirectory)
            }
        }
        .navigationTitle(String(localized: "About"))
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return version.isEmpty ? "—" : "\(version) (\(build))"
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
    NavigationStack {
        AboutView()
    }
}
