//
//  DeviceModels.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import Foundation
import UIKit

struct DeviceInfo {
    private(set) var name = ""
    private(set) var model = ""
    private(set) var localizedModel = ""
    private(set) var systemName = ""
    private(set) var systemVersion = ""
    private(set) var identifierForVendor = "None"
    private(set) var idiom = ""
    private(set) var hardwareModel = ""
    private(set) var screenSize = ""
    private(set) var screenScale: CGFloat = 1.0
}

struct SystemInfo {
    private(set) var uptime: TimeInterval = 0
    private(set) var osVersionString = ""
    private(set) var physicalMemory: UInt64 = 0
    private(set) var processorCount = 0
    private(set) var activeProcessorCount = 0
    private(set) var hostName = ""
    private(set) var cpuBrandString = ""
    private(set) var kernOSVersion = ""
    private(set) var bootTime: Date?
    private(set) var preferredLanguages: [String] = []
    private(set) var localeIdentifier = ""
    private(set) var regionCode = ""
    private(set) var currencyCode = ""
    private(set) var timeZoneIdentifier = ""
    private(set) var secondsFromGMT = 0
    private(set) var isDaylightSaving = false
    private(set) var hwModel = ""                  // hw.model，设备代号
    private(set) var cpuFrequency: UInt64 = 0      // hw.cpufrequency
    private(set) var coreCount = 0                 // machdep.cpu.core_count
    private(set) var threadCount = 0               // machdep.cpu.thread_count
    private(set) var osProductVersion = ""         // kern.osproductversion，如 26.5
    private(set) var osProductBuild = ""           // kern.osproductbuild
    private(set) var isSimulator = false
    private(set) var simulatorDeviceName = ""
    private(set) var cpuUsage: Double = 0          // 总 CPU 使用率 %
    private(set) var processResidentMemory: UInt64 = 0
    private(set) var processVirtualMemory: UInt64 = 0
    private(set) var processAvailableMemory: UInt64 = 0
    private(set) var isJailbroken = false
    private(set) var jailbreakMarkers = ""
    private(set) var clockSkew: TimeInterval = 0

    var uptimeText: String { String(localized: "\(Int(uptime)) sec") }
    var physicalMemoryText: String { DeviceManager.byteString(Int64(physicalMemory)) }
    var bootTimeText: String {
        guard let bootTime = bootTime else { return String(localized: "Unknown") }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: bootTime)
    }
    var languageText: String { preferredLanguages.joined(separator: ", ") }
    var cpuFrequencyText: String { cpuFrequency >= 1_000_000 ? "\(cpuFrequency / 1_000_000) MHz" : String(localized: "Unknown") }
    var cpuUsageText: String { cpuUsage >= 0 ? "≈ " + String(format: "%.1f%%", cpuUsage) : String(localized: "Unknown") }
    var coreThreadText: String { String(localized: "\(coreCount) cores / \(threadCount) threads") }
    var processResidentText: String { DeviceManager.byteString(Int64(processResidentMemory)) }
    var processVirtualText: String { DeviceManager.byteString(Int64(processVirtualMemory)) }
    var processAvailableText: String { DeviceManager.byteString(Int64(processAvailableMemory)) }
    var clockSkewText: String {
        let absSkew = abs(clockSkew)
        if absSkew < 1 { return String(localized: "Normal (< 1 sec deviation)") }
        return clockSkew > 0
            ? String(localized: "Fast by \(Int(absSkew)) sec")
            : String(localized: "Slow by \(Int(absSkew)) sec")
    }
}

struct ScreenInfo {
    private(set) var bounds = ""
    private(set) var nativeBounds = ""
    private(set) var scale: CGFloat = 1.0
    private(set) var nativeScale: CGFloat = 1.0
    private(set) var pixelSize = ""
    private(set) var brightness: CGFloat = 0
    private(set) var availableModes = ""      // 所有支持的分辨率模式

    var scaleText: String { String(format: "%.1f", scale) }
    var nativeScaleText: String { String(format: "%.1f", nativeScale) }
}

struct HardwareInfo {
    private(set) var deviceName = ""          // hw.machine → 机型名（如 iPhone 15 Pro）
    private(set) var screenDiagonal = ""      // 屏幕对角线（英寸，按机型查表）
    private(set) var pageSize = 0             // hw.pagesize
    private(set) var physicalCPU = 0          // hw.physicalcpu
    private(set) var logicalCPU = 0           // hw.logicalcpu
    private(set) var packages = 0             // hw.packages
    private(set) var cpuVendor = ""           // machdep.cpu.vendor（仅 Intel）
    private(set) var cpuFamily = ""           // machdep.cpu.family
    private(set) var cpuModel = ""            // machdep.cpu.model
    private(set) var cpuStepping = ""         // machdep.cpu.stepping
    private(set) var cpuFreqMax: UInt64 = 0   // kern.cpufrequency_max
    private(set) var cpuFreqMin: UInt64 = 0   // kern.cpufrequency_min
    private(set) var gpuName = ""             // Metal 设备名
    private(set) var gpuWorkingSet: UInt64 = 0// 显存（推荐工作集）
    private(set) var gpuMaxThreadsPerGroup = 0
    private(set) var maxRefreshRate = 0       // UIScreen.maximumFramesPerSecond
    private(set) var safeAreaTop: CGFloat = 0
    private(set) var safeAreaBottom: CGFloat = 0
    private(set) var isMultitaskingSupported = false
    private(set) var biometricType = ""       // Face ID / Touch ID / Optic ID / 无
    private(set) var hasPasscode = false

    var gpuWorkingSetText: String { DeviceManager.byteString(Int64(gpuWorkingSet)) }
    var cpuFreqText: String {
        guard cpuFreqMin > 0, cpuFreqMax > 0 else { return String(localized: "Unknown (not exposed on Apple Silicon)") }
        return "\(cpuFreqMin / 1_000_000)-\(cpuFreqMax / 1_000_000) MHz"
    }
    var refreshRateText: String { maxRefreshRate > 0 ? "\(maxRefreshRate) Hz" : String(localized: "Unknown") }
    var safeAreaText: String { String(localized: "Top \(Int(safeAreaTop)) pt / Bottom \(Int(safeAreaBottom)) pt") }
    var detailText: String { cpuVendor.isEmpty ? String(localized: "Unknown") : "\(cpuVendor) family:\(cpuFamily) model:\(cpuModel) stepping:\(cpuStepping)" }
}

struct MemoryInfo {
    private(set) var total: UInt64 = 0
    private(set) var free: UInt64 = 0
    private(set) var active: UInt64 = 0
    private(set) var inactive: UInt64 = 0
    private(set) var wired: UInt64 = 0

    var used: UInt64 { total - free }

    var totalText: String { DeviceManager.byteString(Int64(total)) }
    var usedText: String { "≈ " + DeviceManager.byteString(Int64(used)) }
    var freeText: String { DeviceManager.byteString(Int64(free)) }
    var activeText: String { DeviceManager.byteString(Int64(active)) }
    var inactiveText: String { DeviceManager.byteString(Int64(inactive)) }
    var wiredText: String { DeviceManager.byteString(Int64(wired)) }
}

struct StorageInfo {
    private(set) var totalCapacity: Int64 = 0
    private(set) var availableForImportantUsage: Int64 = 0
    private(set) var availableForOpportunistic: Int64 = 0

    var totalText: String { DeviceManager.byteString(totalCapacity) }
    var availableText: String { DeviceManager.byteString(availableForImportantUsage) }
    var purgeableText: String { DeviceManager.byteString(availableForOpportunistic) }
}

struct NetworkInfo {
    private(set) var connectionType = "Unknown"
    private(set) var isExpensive = false
    private(set) var isConstrained = false
    private(set) var ssid = ""      // WiFi 名称
    private(set) var bssid = ""     // WiFi MAC 地址
    private(set) var localIP = ""   // 本机 IPv4（en0 / pdp_ip0）
}

struct EnvironmentInfo {
    private(set) var isDarkMode = false
    private(set) var displayGamut = ""
    private(set) var horizontalSizeClass = ""
    private(set) var verticalSizeClass = ""
    private(set) var contentSizeCategory = ""
    private(set) var accessibilityContrast = ""
    private(set) var audioRoute = ""
    private(set) var outputVolume: Float = 0
    private(set) var audioSampleRate: Double = 0
    private(set) var calendarIdentifier = ""
    private(set) var firstWeekday = 1
    private(set) var usesMetricSystem = false
    private(set) var temperatureUnit = ""
    private(set) var timeZoneAbbreviation = ""
    private(set) var backgroundRefreshStatus = ""
    private(set) var supportsMultipleScenes = false
    private(set) var isIdleTimerDisabled = false
    private(set) var cameraCount = 0
    private(set) var frontCameraCount = 0
    private(set) var backCameraCount = 0
    private(set) var hasFlash = false
    private(set) var cameraAuthStatus = ""
    private(set) var microphoneCount = 0
    private(set) var inputChannelCount = 0
    private(set) var microphoneAuthStatus = ""
    private(set) var keyboards = ""
    private(set) var timeZoneLocalizedName = ""
    private(set) var nextDSTTransitionText = ""
    private(set) var decimalSeparator = ""
    private(set) var groupingSeparator = ""
    private(set) var launchArguments = ""
    private(set) var audioRecordPermission = ""

    var audioRouteText: String { audioRoute.isEmpty ? String(localized: "Unknown") : audioRoute }
    var outputVolumeText: String { String(format: "%.0f%%", outputVolume * 100) }
    var sampleRateText: String { audioSampleRate > 0 ? "\(Int(audioSampleRate)) Hz" : String(localized: "Unknown") }
}

struct SensorInfo {
    private(set) var isAccelerometerAvailable = false
    private(set) var isGyroAvailable = false
    private(set) var isMagnetometerAvailable = false
    private(set) var isDeviceMotionAvailable = false
    private(set) var isBarometerAvailable = false
    private(set) var accelerometerText = ""
    private(set) var gyroText = ""
    private(set) var magnetometerText = ""
    private(set) var userAccelerationText = ""
    private(set) var rotationRateText = ""
    private(set) var attitudeText = ""
    private(set) var relativeAltitudeText = ""
    private(set) var pressureText = ""
    private(set) var motionActivityText = ""
    private(set) var latitudeText = ""
    private(set) var longitudeText = ""
    private(set) var altitudeText = ""
    private(set) var courseText = ""
    private(set) var speedText = ""
    private(set) var horizontalAccuracyText = ""
    private(set) var locationAuthStatus = ""
    private(set) var accuracyAuthorizationText = ""

    var availabilityText: String {
        let available: [String] = [
            isAccelerometerAvailable ? String(localized: "Accelerometer") : nil,
            isGyroAvailable ? String(localized: "Gyroscope") : nil,
            isMagnetometerAvailable ? String(localized: "Magnetometer") : nil,
            isDeviceMotionAvailable ? String(localized: "Device Motion") : nil,
            isBarometerAvailable ? String(localized: "Barometer") : nil,
        ].compactMap { $0 }
        return available.isEmpty ? String(localized: "No sensors available") : available.joined(separator: " / ")
    }
}

struct CarrierInfo {
    private(set) var carrierName = ""
    private(set) var mobileCountryCode = ""
    private(set) var mobileNetworkCode = ""
    private(set) var isoCountryCode = ""
    private(set) var radioAccessTechnology = ""
}

struct BundleInfo {
    private(set) var version = ""
    private(set) var build = ""
    private(set) var bundleIdentifier = ""
    private(set) var displayName = ""
    private(set) var bundleName = ""
    private(set) var executable = ""
    private(set) var minimumOSVersion = ""
    private(set) var sdkName = ""
    private(set) var homeDirectory = ""
    private(set) var documentsDirectory = ""
    private(set) var cachesDirectory = ""
    private(set) var tmpDirectory = ""
    private(set) var applicationState = ""
    private(set) var backgroundTimeRemaining: TimeInterval = 0
}

