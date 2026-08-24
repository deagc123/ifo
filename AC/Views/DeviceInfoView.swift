//
//  DeviceInfoView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct DeviceInfoView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("设备基础信息") {
                InfoRow(label: "用户名称", value: manager.deviceInfo.name)
                InfoRow(label: "型号", value: manager.deviceInfo.model)
                InfoRow(label: "本地化型号", value: manager.deviceInfo.localizedModel)
                InfoRow(label: "系统名称", value: manager.deviceInfo.systemName)
                InfoRow(label: "系统版本", value: manager.deviceInfo.systemVersion)
                InfoRow(label: "供应商 ID", value: manager.deviceInfo.identifierForVendor)
                InfoRow(label: "界面样式", value: manager.deviceInfo.idiom)
                InfoRow(label: "硬件型号标识", value: manager.deviceInfo.hardwareModel)
            }

            Section("实时状态") {
                InfoRow(label: "当前方向", value: manager.currentOrientation)
                InfoRow(label: "电池电量", value: batteryText)
                InfoRow(label: "电池状态", value: manager.batteryState)
                InfoRow(label: "接近传感器", value: manager.proximityState ? "有物体靠近" : "无物体")
            }

            Section("屏幕") {
                InfoRow(label: "屏幕尺寸 (pt)", value: manager.deviceInfo.screenSize)
                InfoRow(label: "屏幕 Scale", value: String(format: "%.1f", manager.deviceInfo.screenScale))
            }
        }
        .navigationTitle("设备信息")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private var batteryText: String {
        manager.batteryLevel >= 0 ? "\(Int(manager.batteryLevel * 100))%" : "未知"
    }
}

#Preview {
    DeviceInfoView()
}
