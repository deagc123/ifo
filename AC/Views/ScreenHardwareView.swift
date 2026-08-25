//
//  ScreenHardwareView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct ScreenHardwareView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("Display") {
                InfoRow(label: "Screen Size", value: manager.hardwareInfo.screenDiagonal.isEmpty ? "—" : manager.hardwareInfo.screenDiagonal)
                InfoRow(label: "Logical Size (pt)", value: manager.screenInfo.bounds)
                InfoRow(label: "Physical Size (px)", value: manager.screenInfo.nativeBounds)
                InfoRow(label: "Scale", value: manager.screenInfo.scaleText)
                InfoRow(label: "Native Scale", value: manager.screenInfo.nativeScaleText)
                InfoRow(label: "Pixel Size", value: manager.screenInfo.pixelSize)
                InfoRow(label: "Available Modes", value: manager.screenInfo.availableModes.isEmpty ? String(localized: "Unknown") : manager.screenInfo.availableModes)
                InfoRow(label: "Brightness", value: "\(Int(manager.currentBrightness * 100))%")
            }

            Section("Memory") {
                InfoRow(label: "Physical Memory", value: manager.memoryInfo.totalText)
                InfoRow(label: "Used Memory", value: manager.memoryInfo.usedText)
                InfoRow(label: "Free Memory", value: manager.memoryInfo.freeText)
                InfoRow(label: "Active Memory", value: manager.memoryInfo.activeText)
                InfoRow(label: "Inactive Memory", value: manager.memoryInfo.inactiveText)
                InfoRow(label: "Wired Memory", value: manager.memoryInfo.wiredText)
                RealtimeChartCard(
                    title: String(localized: "Used Memory"),
                    seriesCount: 1,
                    colors: [.accentColor],
                    interval: 1.0
                ) {
                    [manager.currentMemoryUsageRatio()]
                }
            }

            Section("Storage") {
                InfoRow(label: "Total Capacity", value: manager.storageInfo.totalText)
                InfoRow(label: "Available", value: manager.storageInfo.availableText)
                InfoRow(label: "Purgeable", value: manager.storageInfo.purgeableText)
            }

            Section("Network") {
                InfoRow(label: "Connection Type", value: manager.currentConnectionType)
                InfoRow(label: "Local IP", value: manager.networkInfo.localIP)
                InfoRow(label: "Public IP", value: manager.externalIPAddress)
                InfoRow(label: "DNS Servers", value: manager.dnsServers)
                InfoRow(label: "Expensive Network", value: manager.networkInfo.isExpensive ? String(localized: "Yes") : String(localized: "No"))
                InfoRow(label: "Constrained Network", value: manager.networkInfo.isConstrained ? String(localized: "Yes") : String(localized: "No"))
            }

            Section("Network Interfaces") {
                Text(manager.networkInterfaces)
                    .font(.footnote)
                    .monospaced()
                    .foregroundColor(.secondary)
            }

            Section("WiFi") {
                InfoRow(label: "SSID", value: manager.networkInfo.ssid)
                InfoRow(label: "BSSID", value: manager.networkInfo.bssid.isEmpty ? String(localized: "Unknown") : manager.networkInfo.bssid)
            }

            Section("Interface Environment") {
                InfoRow(label: "Dark Mode", value: manager.environmentInfo.isDarkMode ? String(localized: "On") : String(localized: "Off"))
                InfoRow(label: "Color Gamut", value: manager.environmentInfo.displayGamut)
                InfoRow(label: "Horizontal Size Class", value: manager.environmentInfo.horizontalSizeClass)
                InfoRow(label: "Vertical Size Class", value: manager.environmentInfo.verticalSizeClass)
                InfoRow(label: "Font Size", value: manager.environmentInfo.contentSizeCategory)
                InfoRow(label: "Contrast", value: manager.environmentInfo.accessibilityContrast)
            }

            Section("Audio Environment") {
                InfoRow(label: "Output Device", value: manager.environmentInfo.audioRouteText)
                InfoRow(label: "Output Volume", value: manager.environmentInfo.outputVolumeText)
                InfoRow(label: "Sample Rate", value: manager.environmentInfo.sampleRateText)
            }

            Section("Camera & Microphone") {
                InfoRow(label: "Cameras", value: String(localized: "\(manager.environmentInfo.cameraCount) (front \(manager.environmentInfo.frontCameraCount) / back \(manager.environmentInfo.backCameraCount))"))
                InfoRow(label: "Flash", value: manager.environmentInfo.hasFlash ? String(localized: "Supported") : String(localized: "Not Supported"))
                InfoRow(label: "Camera Permission", value: manager.environmentInfo.cameraAuthStatus)
                InfoRow(label: "Microphones", value: "\(manager.environmentInfo.microphoneCount)")
                InfoRow(label: "Input Channels", value: "\(manager.environmentInfo.inputChannelCount)")
                InfoRow(label: "Microphone Permission", value: manager.environmentInfo.microphoneAuthStatus)
                InfoRow(label: "Recording Permission", value: manager.environmentInfo.audioRecordPermission)
            }

            Section("Calendar & System Settings") {
                InfoRow(label: "Calendar", value: manager.environmentInfo.calendarIdentifier)
                InfoRow(label: "First Weekday", value: weekdayText(manager.environmentInfo.firstWeekday))
                InfoRow(label: "Metric Units", value: manager.environmentInfo.usesMetricSystem ? String(localized: "Yes") : String(localized: "No"))
                InfoRow(label: "Temperature Unit", value: manager.environmentInfo.temperatureUnit)
                InfoRow(label: "Time Zone Abbr", value: manager.environmentInfo.timeZoneAbbreviation)
                InfoRow(label: "Keyboards", value: manager.environmentInfo.keyboards)
            }

            Section("Carrier") {
                InfoRow(label: "Carrier", value: manager.carrierInfo.carrierName)
                InfoRow(label: "MCC", value: manager.carrierInfo.mobileCountryCode)
                InfoRow(label: "MNC", value: manager.carrierInfo.mobileNetworkCode)
                InfoRow(label: "Country Code", value: manager.carrierInfo.isoCountryCode)
                InfoRow(label: "Radio Technology", value: manager.carrierInfo.radioAccessTechnology)
            }
        }
        .navigationTitle("Screen & Hardware")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private func weekdayText(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return String(localized: "Unknown") }
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[weekday - 1]
    }
}

#Preview {
    ScreenHardwareView()
}
