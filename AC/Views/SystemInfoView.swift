//
//  SystemInfoView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct SystemInfoView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("Process & System") {
                InfoRow(label: "Uptime", value: manager.systemInfo.uptimeText)
                InfoRow(label: "OS Version", value: manager.systemInfo.osVersionString)
                InfoRow(label: "Product Version", value: manager.systemInfo.osProductVersion.isEmpty ? String(localized: "Unknown") : manager.systemInfo.osProductVersion)
                InfoRow(label: "Build Number", value: manager.systemInfo.osProductBuild.isEmpty ? String(localized: "Unknown") : manager.systemInfo.osProductBuild)
                InfoRow(label: "Physical Memory", value: manager.systemInfo.physicalMemoryText)
                InfoRow(label: "CPU Usage", value: manager.systemInfo.cpuUsageText)
                RealtimeChartCard(
                    title: String(localized: "CPU Usage"),
                    seriesCount: 1,
                    colors: [.accentColor],
                    interval: 0.5
                ) {
                    [min(max(DeviceManager.cpuUsage() / 100, 0), 1)]
                }
                InfoRow(label: "CPU Frequency", value: manager.systemInfo.cpuFrequencyText)
                InfoRow(label: "CPU Cores", value: String(localized: "\(manager.systemInfo.processorCount) cores (\(manager.systemInfo.activeProcessorCount) active)"))
                InfoRow(label: "Cores / Threads", value: manager.systemInfo.coreThreadText)
                InfoRow(label: "CPU Brand", value: manager.systemInfo.cpuBrandString)
                InfoRow(label: "Hardware Model", value: manager.systemInfo.hwModel.isEmpty ? String(localized: "Unknown") : manager.systemInfo.hwModel)
                InfoRow(label: "Kernel Version", value: manager.systemInfo.kernOSVersion)
                InfoRow(label: "Boot Time", value: manager.systemInfo.bootTimeText)
                InfoRow(label: "Host Name", value: manager.systemInfo.hostName)
                InfoRow(label: "Runtime", value: manager.systemInfo.isSimulator ? String(localized: "Simulator (\(manager.systemInfo.simulatorDeviceName))") : String(localized: "Physical Device"))
                InfoRow(label: "Thermal State", value: manager.thermalState)
                InfoRow(label: "Low Power Mode", value: manager.lowPowerMode ? String(localized: "On") : String(localized: "Off"))
            }

            Section("Process Memory") {
                InfoRow(label: "Resident Memory", value: manager.systemInfo.processResidentText)
                InfoRow(label: "Virtual Memory", value: manager.systemInfo.processVirtualText)
                InfoRow(label: "Available Memory", value: manager.systemInfo.processAvailableText)
            }

            Section("Hardware Details") {
                InfoRow(label: "Device Model", value: manager.hardwareInfo.deviceName)
                InfoRow(label: "Page Size", value: String(localized: "\(manager.hardwareInfo.pageSize) bytes"))
                InfoRow(label: "Physical/Logical Cores", value: "\(manager.hardwareInfo.physicalCPU) / \(manager.hardwareInfo.logicalCPU)")
                InfoRow(label: "Packages", value: "\(manager.hardwareInfo.packages)")
                InfoRow(label: "CPU Details", value: manager.hardwareInfo.detailText)
                InfoRow(label: "CPU Frequency Range", value: manager.hardwareInfo.cpuFreqText)
                InfoRow(label: "GPU Name", value: manager.hardwareInfo.gpuName)
                InfoRow(label: "GPU Memory", value: manager.hardwareInfo.gpuWorkingSetText)
                InfoRow(label: "Max Threads per Group", value: "\(manager.hardwareInfo.gpuMaxThreadsPerGroup)")
                InfoRow(label: "Max Refresh Rate", value: manager.hardwareInfo.refreshRateText)
                InfoRow(label: "Safe Area", value: manager.hardwareInfo.safeAreaText)
                InfoRow(label: "Multitasking", value: manager.hardwareInfo.isMultitaskingSupported ? String(localized: "Supported") : String(localized: "Not Supported"))
                InfoRow(label: "Biometrics", value: manager.hardwareInfo.biometricType)
                InfoRow(label: "Passcode Set", value: manager.hardwareInfo.hasPasscode ? String(localized: "Yes") : String(localized: "No"))
            }

            Section("Locale & Time Zone") {
                InfoRow(label: "Preferred Languages", value: manager.systemInfo.languageText)
                InfoRow(label: "Locale", value: manager.systemInfo.localeIdentifier)
                InfoRow(label: "Region", value: manager.systemInfo.regionCode)
                InfoRow(label: "Currency", value: manager.systemInfo.currencyCode)
                InfoRow(label: "Time Zone", value: manager.systemInfo.timeZoneIdentifier)
                InfoRow(label: "Time Zone Name", value: manager.environmentInfo.timeZoneLocalizedName)
                InfoRow(label: "GMT Offset", value: String(localized: "\(manager.systemInfo.secondsFromGMT / 3600) hours"))
                InfoRow(label: "Daylight Saving", value: manager.systemInfo.isDaylightSaving ? String(localized: "In Effect") : String(localized: "Not in Effect"))
                InfoRow(label: "Next Transition", value: manager.environmentInfo.nextDSTTransitionText)
                InfoRow(label: "Decimal Separator", value: manager.environmentInfo.decimalSeparator)
                InfoRow(label: "Grouping Separator", value: manager.environmentInfo.groupingSeparator)
            }

            Section("Security & Clock") {
                InfoRow(label: "Jailbreak Detection", value: manager.systemInfo.isJailbroken ? String(localized: "Possibly Jailbroken") : String(localized: "Not Jailbroken"))
                InfoRow(label: "Jailbreak Markers", value: manager.systemInfo.jailbreakMarkers.isEmpty ? String(localized: "None") : manager.systemInfo.jailbreakMarkers)
                InfoRow(label: "Clock Skew", value: manager.systemInfo.clockSkewText)
            }

            if !manager.errors.isEmpty {
                Section("Errors") {
                    ForEach(manager.errors, id: \.self) { error in
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("System Info")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    SystemInfoView()
}
