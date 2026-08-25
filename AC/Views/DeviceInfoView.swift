//
//  DeviceInfoView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct DeviceInfoView: View {
    @ObservedObject private var manager = DeviceManager.shared
    @State private var showShare = false

    var body: some View {
        List {
            Section("Device Basics") {
                InfoRow(label: "Name", value: manager.deviceInfo.name)
                InfoRow(label: "Model", value: manager.deviceInfo.model)
                InfoRow(label: "Localized Model", value: manager.deviceInfo.localizedModel)
                InfoRow(label: "System Name", value: manager.deviceInfo.systemName)
                InfoRow(label: "System Version", value: manager.deviceInfo.systemVersion)
                InfoRow(label: "Vendor ID", value: manager.deviceInfo.identifierForVendor)
                InfoRow(label: "Interface Idiom", value: manager.deviceInfo.idiom)
                InfoRow(label: "Hardware Identifier", value: manager.deviceInfo.hardwareModel)
            }

            Section("Live Status") {
                InfoRow(label: "Orientation", value: manager.currentOrientation)
                InfoRow(label: "Battery Level", value: batteryText)
                InfoRow(label: "Battery State", value: manager.batteryState)
                InfoRow(label: "Proximity", value: manager.proximityState ? String(localized: "Object Near") : String(localized: "No Object"))
            }

            Section("Display") {
                InfoRow(label: "Screen Size (pt)", value: manager.deviceInfo.screenSize)
                InfoRow(label: "Screen Scale", value: String(format: "%.1f", manager.deviceInfo.screenScale))
            }
        }
        .navigationTitle("Device Info")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "Share Device Info"))
            }
        }
        .fullScreenCover(isPresented: $showShare) {
            DeviceShareView()
        }
    }

    private var batteryText: String {
        manager.batteryLevel >= 0 ? "\(Int(manager.batteryLevel * 100))%" : String(localized: "Unknown")
    }
}

#Preview {
    DeviceInfoView()
}
