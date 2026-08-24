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
            Section("应用信息") {
                InfoRow(label: "版本号", value: manager.bundleInfo.version)
                InfoRow(label: "Build", value: manager.bundleInfo.build)
                InfoRow(label: "Bundle ID", value: manager.bundleInfo.bundleIdentifier)
                InfoRow(label: "显示名", value: manager.bundleInfo.displayName)
                InfoRow(label: "包名", value: manager.bundleInfo.bundleName)
                InfoRow(label: "可执行文件", value: manager.bundleInfo.executable)
                InfoRow(label: "最低系统", value: manager.bundleInfo.minimumOSVersion)
                InfoRow(label: "编译 SDK", value: manager.bundleInfo.sdkName)
                InfoRow(label: "启动参数", value: manager.environmentInfo.launchArguments.isEmpty ? "无" : manager.environmentInfo.launchArguments)
            }

            Section("运行状态") {
                InfoRow(label: "应用状态", value: manager.bundleInfo.applicationState)
                InfoRow(label: "后台剩余时间", value: backgroundTimeText)
                InfoRow(label: "后台刷新", value: manager.environmentInfo.backgroundRefreshStatus)
                InfoRow(label: "通知权限", value: manager.notificationAuthStatus)
                InfoRow(label: "多场景支持", value: manager.environmentInfo.supportsMultipleScenes ? "支持" : "不支持")
                InfoRow(label: "禁止屏幕休眠", value: manager.environmentInfo.isIdleTimerDisabled ? "是" : "否")
            }

            Section("广告与推送") {
                InfoRow(label: "IDFA", value: manager.idfa)
                InfoRow(label: "追踪授权", value: manager.idfaAuthStatus)
                InfoRow(label: "推送状态", value: manager.pushStatus)
                InfoRow(label: "DeviceToken", value: manager.pushToken)
            }

            Section("沙盒路径") {
                InfoRow(label: "Home", value: manager.bundleInfo.homeDirectory)
                InfoRow(label: "Documents", value: manager.bundleInfo.documentsDirectory)
                InfoRow(label: "Caches", value: manager.bundleInfo.cachesDirectory)
                InfoRow(label: "Tmp", value: manager.bundleInfo.tmpDirectory)
            }
        }
        .navigationTitle("当前 App")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private var backgroundTimeText: String {
        let remaining = manager.bundleInfo.backgroundTimeRemaining
        guard remaining.isFinite, remaining >= 0, remaining < Double(Int.max) else {
            return "前台运行，无限制"
        }
        return "\(Int(remaining)) 秒"
    }
}

#Preview {
    BundleInfoView()
}
