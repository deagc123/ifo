//
//  DeviceManager.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import Foundation
import UIKit
import Combine
import Network
import NetworkExtension
import CoreTelephony
import CoreLocation
import CoreMotion
import AVFoundation
import Metal
import LocalAuthentication
import UserNotifications
import Darwin
import MachO

class DeviceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = DeviceManager()

    // MARK: - 数据模型（静态信息快照）
    @Published var deviceInfo = DeviceInfo()
    @Published var systemInfo = SystemInfo()
    @Published var screenInfo = ScreenInfo()
    @Published var hardwareInfo = HardwareInfo()
    @Published var memoryInfo = MemoryInfo()
    @Published var storageInfo = StorageInfo()
    @Published var networkInfo = NetworkInfo()
    @Published var carrierInfo = CarrierInfo()
    @Published var bundleInfo = BundleInfo()
    @Published var environmentInfo = EnvironmentInfo()
    @Published var sensorInfo = SensorInfo()

    // MARK: - 动态信息（单独 @Published，不走 struct）
    @Published var currentOrientation = ""
    @Published var batteryLevel: Float = -1
    @Published var batteryState = ""
    @Published var proximityState = false
    @Published var thermalState = ""
    @Published var lowPowerMode = false
    @Published var currentBrightness: CGFloat = 0
    @Published var currentConnectionType = String(localized: "Unknown")

    // MARK: - 网络细节（单独 @Published，异步/一次计算）
    @Published var networkInterfaces = String(localized: "Unknown")
    @Published var dnsServers = String(localized: "Unknown")
    @Published var externalIPAddress = String(localized: "Unknown")

    // MARK: - 通知授权（查询状态，非推送注册）
    @Published var notificationAuthStatus = String(localized: "Unknown")

    // MARK: - 全局状态
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errors: [String] = []

    // MARK: - 内部引用
    private let device = UIDevice.current
    private var monitor: NWPathMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var pollingCancellable: AnyCancellable?
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let motionActivityManager = CMMotionActivityManager()
    private var lastLocation: CLLocation?
    private var lastActivity: CMMotionActivity?
    private var lastBarometer: CMAltitudeData?

    override init() {
        super.init()
        locationManager.delegate = self
        requestLocationAuthorization()
        startMonitoring()
        refreshAll()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - 总刷新入口
    func refreshAll() {
        isLoading = true
        refreshDeviceInfo()
        refreshSystemInfo()
        refreshScreenInfo()
        refreshHardwareInfo()
        refreshMemoryInfo()
        refreshStorageInfo()
        refreshNetworkInfo()
        refreshCarrierInfo()
        refreshBundleInfo()
        refreshEnvironmentInfo()
        refreshNetworkDetails()
        refreshSensors()
        refreshNotificationSettings()
        lastUpdated = Date()
        isLoading = false
    }

    // MARK: - 设备信息（UIDevice + sysctl）
    private func refreshDeviceInfo() {
        let screen = UIScreen.main
        deviceInfo = DeviceInfo(
            name: device.name,
            model: device.model,
            localizedModel: device.localizedModel,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            identifierForVendor: device.identifierForVendor?.uuidString ?? "None",
            idiom: idiomString(device.userInterfaceIdiom),
            hardwareModel: DeviceManager.sysctlString("hw.machine"),
            screenSize: "\(Int(screen.bounds.width)) x \(Int(screen.bounds.height))",
            screenScale: screen.scale
        )
    }

    // MARK: - 系统信息（ProcessInfo + sysctl + NSLocale + TimeZone）
    private func refreshSystemInfo() {
        let p = ProcessInfo.processInfo
        let taskMemory = DeviceManager.taskMemory()
        let jailbreak = DeviceManager.jailbreakDetection()
        let bootTime = DeviceManager.bootTime()
        var clockSkew: TimeInterval = 0
        if let bootTime = bootTime {
            let estimatedNow = bootTime.timeIntervalSince1970 + p.systemUptime
            clockSkew = Date().timeIntervalSince1970 - estimatedNow
        }
        systemInfo = SystemInfo(
            uptime: p.systemUptime,
            osVersionString: p.operatingSystemVersionString,
            physicalMemory: p.physicalMemory,
            processorCount: p.processorCount,
            activeProcessorCount: p.activeProcessorCount,
            hostName: p.hostName,
            cpuBrandString: Self.cpuBrand(),
            kernOSVersion: DeviceManager.sysctlString("kern.osversion"),
            bootTime: bootTime,
            preferredLanguages: NSLocale.preferredLanguages,
            localeIdentifier: NSLocale.current.identifier,
            regionCode: NSLocale.current.regionCode ?? "",
            currencyCode: NSLocale.current.currencyCode ?? "",
            timeZoneIdentifier: TimeZone.current.identifier,
            secondsFromGMT: TimeZone.current.secondsFromGMT(),
            isDaylightSaving: TimeZone.current.isDaylightSavingTime(),
            hwModel: DeviceManager.sysctlString("hw.model"),
            cpuFrequency: DeviceManager.sysctlUInt64("hw.cpufrequency"),
            coreCount: Int(DeviceManager.sysctlInt32("machdep.cpu.core_count")),
            threadCount: Int(DeviceManager.sysctlInt32("machdep.cpu.thread_count")),
            osProductVersion: DeviceManager.sysctlString("kern.osproductversion"),
            osProductBuild: DeviceManager.sysctlString("kern.osproductbuild"),
            isSimulator: Self.isSimulator,
            simulatorDeviceName: p.environment["SIMULATOR_DEVICE_NAME"] ?? String(localized: "Not Simulator"),
            cpuUsage: DeviceManager.cpuUsage(),
            processResidentMemory: taskMemory.resident,
            processVirtualMemory: taskMemory.virtual,
            processAvailableMemory: UInt64(os_proc_available_memory()),
            isJailbroken: jailbreak.isJailbroken,
            jailbreakMarkers: jailbreak.markers,
            clockSkew: clockSkew
        )
    }

    // MARK: - 屏幕信息（UIScreen）
    private func refreshScreenInfo() {
        let s = UIScreen.main
        let mode = s.currentMode
        screenInfo = ScreenInfo(
            bounds: "\(Int(s.bounds.width)) x \(Int(s.bounds.height))",
            nativeBounds: "\(Int(s.nativeBounds.width)) x \(Int(s.nativeBounds.height))",
            scale: s.scale,
            nativeScale: s.nativeScale,
            pixelSize: "\(Int(mode?.size.width ?? 0)) x \(Int(mode?.size.height ?? 0))",
            brightness: s.brightness,
            availableModes: s.availableModes
                .map { "\(Int($0.size.width))x\(Int($0.size.height))" }
                .joined(separator: ", ")
        )
    }

    // MARK: - 硬件详情（sysctl 扩展 + Metal GPU + 刷新率 + 安全区域）
    private func refreshHardwareInfo() {
        let identifier = DeviceManager.sysctlString("hw.machine")
        let metalDevice = MTLCreateSystemDefaultDevice()
        var safeTop: CGFloat = 0
        var safeBottom: CGFloat = 0
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            safeTop = window.safeAreaInsets.top
            safeBottom = window.safeAreaInsets.bottom
        }
        hardwareInfo = HardwareInfo(
            deviceName: DeviceManager.friendlyDeviceName(identifier),
            screenDiagonal: Self.screenDiagonal(identifier) ?? "",
            pageSize: Int(DeviceManager.sysctlInt32("hw.pagesize")),
            physicalCPU: Int(DeviceManager.sysctlInt32("hw.physicalcpu")),
            logicalCPU: Int(DeviceManager.sysctlInt32("hw.logicalcpu")),
            packages: Int(DeviceManager.sysctlInt32("hw.packages")),
            cpuVendor: DeviceManager.sysctlString("machdep.cpu.vendor"),
            cpuFamily: DeviceManager.sysctlString("machdep.cpu.family"),
            cpuModel: DeviceManager.sysctlString("machdep.cpu.model"),
            cpuStepping: DeviceManager.sysctlString("machdep.cpu.stepping"),
            cpuFreqMax: DeviceManager.sysctlUInt64("kern.cpufrequency_max"),
            cpuFreqMin: DeviceManager.sysctlUInt64("kern.cpufrequency_min"),
            gpuName: metalDevice?.name ?? "None",
            gpuWorkingSet: metalDevice?.recommendedMaxWorkingSetSize ?? 0,
            gpuMaxThreadsPerGroup: Int(metalDevice?.maxThreadsPerThreadgroup.width ?? 0),
            maxRefreshRate: Int(UIScreen.main.maximumFramesPerSecond),
            safeAreaTop: safeTop,
            safeAreaBottom: safeBottom,
            isMultitaskingSupported: device.isMultitaskingSupported,
            biometricType: Self.biometricString(),
            hasPasscode: Self.passcodeSet()
        )
    }

    // MARK: - 内存信息（host_statistics64）
    private func refreshMemoryInfo() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            errors.append(String(localized: "Failed to read memory info"))
            return
        }
        let pageSize = UInt64(vm_page_size)
        memoryInfo = MemoryInfo(
            total: ProcessInfo.processInfo.physicalMemory,
            free: UInt64(stats.free_count) * pageSize,
            active: UInt64(stats.active_count) * pageSize,
            inactive: UInt64(stats.inactive_count) * pageSize,
            wired: UInt64(stats.wire_count) * pageSize
        )
    }

    // MARK: - 磁盘信息（FileManager volume）
    private func refreshStorageInfo() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityForOpportunisticUsageKey,
            ])
            storageInfo = StorageInfo(
                totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                availableForImportantUsage: Int64(values.volumeAvailableCapacityForImportantUsage ?? 0),
                availableForOpportunistic: Int64(values.volumeAvailableCapacityForOpportunisticUsage ?? 0)
            )
        } catch {
            errors.append(String(localized: "Failed to read disk info: \(error.localizedDescription)"))
        }
    }

    // MARK: - 网络信息（NWPathMonitor + WiFi SSID）
    private func refreshNetworkInfo() {
        if let path = monitor?.currentPath {
            updateNetworkInfo(path)
        }
        refreshWiFiInfo()
    }

    private func updateNetworkInfo(_ path: Network.NWPath) {
        var connectionType = String(localized: "Unknown")
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wifi) {
                connectionType = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                connectionType = String(localized: "Cellular")
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = String(localized: "Wired")
            } else {
                connectionType = String(localized: "Other")
            }
        case .unsatisfied:
            connectionType = String(localized: "No Network")
        case .requiresConnection:
            connectionType = String(localized: "Requires Connection")
        @unknown default:
            connectionType = String(localized: "Unknown")
        }
        networkInfo = NetworkInfo(
            connectionType: connectionType,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            ssid: networkInfo.ssid,
            bssid: networkInfo.bssid,
            localIP: DeviceManager.localIPAddress()
        )
        currentConnectionType = connectionType
    }

    // MARK: - 网络细节（接口列表 / DNS / 公网 IP）
    private func refreshNetworkDetails() {
        networkInterfaces = DeviceManager.interfaceList()
        dnsServers = DeviceManager.dnsServers()
        refreshExternalIP()
    }

    // MARK: - 公网 IP（多源轮询，首个成功生效；单一服务可能超时/被墙）
    private static let ipCheckEndpoints = [
        "https://api.ipify.org",
        "https://ipinfo.io/ip",
        "https://ip.3322.net",
        "https://myip.ipip.net",
    ]

    func refreshExternalIP() {
        fetchExternalIP(from: Self.ipCheckEndpoints)
    }

    private func fetchExternalIP(from endpoints: [String]) {
        guard let first = endpoints.first else {
            externalIPAddress = String(localized: "Failed (all sources unreachable)")
            return
        }
        guard let url = URL(string: first) else {
            fetchExternalIP(from: Array(endpoints.dropFirst()))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let ip = Self.extractIPv4(from: data) {
                    self.externalIPAddress = ip
                } else {
                    self.fetchExternalIP(from: Array(endpoints.dropFirst()))
                }
            }
        }.resume()
    }

    nonisolated static func extractIPv4(from data: Data?) -> String? {
        guard let data = data, let text = String(data: data, encoding: .utf8) else { return nil }
        let pattern = "(?:(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    // MARK: - WiFi SSID（需 wifi-info entitlement + 定位权限 + 真机）
    private func refreshWiFiInfo() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            applySSID(String(localized: "Not available (location permission required)"), bssid: "")
            return
        }
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let network = network, !network.ssid.isEmpty {
                    self.applySSID(network.ssid, bssid: network.bssid)
                } else {
                    self.applySSID(String(localized: "Not available (no WiFi or restricted)"), bssid: "")
                }
            }
        }
    }

    private func applySSID(_ ssid: String, bssid: String) {
        networkInfo = NetworkInfo(
            connectionType: networkInfo.connectionType,
            isExpensive: networkInfo.isExpensive,
            isConstrained: networkInfo.isConstrained,
            ssid: ssid,
            bssid: bssid,
            localIP: networkInfo.localIP
        )
    }

    // MARK: - 环境信息（UI 外观 + 音频 + 日历/设置 + 应用能力）
    private func refreshEnvironmentInfo() {
        var traits = UITraitCollection.current
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            traits = window.traitCollection
        }

        var displayGamut = String(localized: "Other")
        if traits.displayGamut == .P3 {
            displayGamut = String(localized: "P3 Wide Color")
        }

        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute.outputs.first?.portType.rawValue ?? ""
        let weekday = Calendar.current.firstWeekday
        let calendarIdentifier = calendarString(Calendar.current.identifier)
        let keyboards = (UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String]) ?? []

        let videoDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera,
                          .builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        let audioInputs = session.availableInputs ?? []

        environmentInfo = EnvironmentInfo(
            isDarkMode: traits.userInterfaceStyle == .dark,
            displayGamut: displayGamut,
            horizontalSizeClass: sizeClassString(traits.horizontalSizeClass),
            verticalSizeClass: sizeClassString(traits.verticalSizeClass),
            contentSizeCategory: traits.preferredContentSizeCategory.rawValue,
            accessibilityContrast: traits.accessibilityContrast == .high ? String(localized: "High Contrast") : String(localized: "Standard"),
            audioRoute: route,
            outputVolume: session.outputVolume,
            audioSampleRate: session.sampleRate,
            calendarIdentifier: calendarIdentifier,
            firstWeekday: weekday,
            usesMetricSystem: UserDefaults.standard.bool(forKey: "AppleMetricUnits"),
            temperatureUnit: UserDefaults.standard.string(forKey: "AppleTemperatureUnit") ?? String(localized: "Unknown"),
            timeZoneAbbreviation: TimeZone.current.abbreviation() ?? String(localized: "Unknown"),
            backgroundRefreshStatus: backgroundRefreshString(UIApplication.shared.backgroundRefreshStatus),
            supportsMultipleScenes: UIApplication.shared.supportsMultipleScenes,
            isIdleTimerDisabled: UIApplication.shared.isIdleTimerDisabled,
            cameraCount: videoDevices.count,
            frontCameraCount: videoDevices.filter { $0.position == .front }.count,
            backCameraCount: videoDevices.filter { $0.position == .back }.count,
            hasFlash: AVCaptureDevice.default(for: .video)?.hasFlash ?? false,
            cameraAuthStatus: mediaAuthString(AVCaptureDevice.authorizationStatus(for: .video)),
            microphoneCount: audioInputs.count,
            inputChannelCount: Int(session.maximumInputNumberOfChannels),
            microphoneAuthStatus: mediaAuthString(AVCaptureDevice.authorizationStatus(for: .audio)),
            keyboards: keyboards.isEmpty ? String(localized: "None") : keyboards.joined(separator: ", "),
            timeZoneLocalizedName: TimeZone.current.localizedName(for: .shortGeneric, locale: .current) ?? String(localized: "Unknown"),
            nextDSTTransitionText: nextDSTString(),
            decimalSeparator: Locale.current.decimalSeparator ?? ".",
            groupingSeparator: Locale.current.groupingSeparator ?? ",",
            launchArguments: ProcessInfo.processInfo.arguments.joined(separator: " "),
            audioRecordPermission: audioRecordPermissionString(AVAudioSession.sharedInstance().recordPermission)
        )
    }

    // MARK: - 运营商信息（CoreTelephony）
    private func refreshCarrierInfo() {
        let ct = CTTelephonyNetworkInfo()
        var name = ""
        var mcc = ""
        var mnc = ""
        var iso = ""
        if let providers = ct.serviceSubscriberCellularProviders,
           let first = providers.values.first {
            name = first.carrierName ?? String(localized: "Unknown")
            mcc = first.mobileCountryCode ?? ""
            mnc = first.mobileNetworkCode ?? ""
            iso = first.isoCountryCode ?? ""
        }
        carrierInfo = CarrierInfo(
            carrierName: name,
            mobileCountryCode: mcc,
            mobileNetworkCode: mnc,
            isoCountryCode: iso,
            radioAccessTechnology: radioTechString(ct.serviceCurrentRadioAccessTechnology?.values.first)
        )
    }

    // MARK: - 当前 App 信息（Bundle.main + UIApplication + 沙盒）
    private func refreshBundleInfo() {
        let bundle = Bundle.main
        let fm = FileManager.default
        bundleInfo = BundleInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            bundleIdentifier: bundle.bundleIdentifier ?? "",
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "",
            bundleName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
            executable: bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "",
            minimumOSVersion: bundle.object(forInfoDictionaryKey: "MinimumOSVersion") as? String ?? "",
            sdkName: bundle.object(forInfoDictionaryKey: "DTSDKName") as? String ?? "",
            homeDirectory: NSHomeDirectory(),
            documentsDirectory: fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "",
            cachesDirectory: fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? "",
            tmpDirectory: NSTemporaryDirectory(),
            applicationState: appStateString(UIApplication.shared.applicationState),
            backgroundTimeRemaining: UIApplication.shared.backgroundTimeRemaining
        )
    }

    // MARK: - 定位授权（SSID 获取的前置条件）
    private func requestLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // MARK: - 动态信息监听
    private func startMonitoring() {
        device.beginGeneratingDeviceOrientationNotifications()
        device.isBatteryMonitoringEnabled = true
        device.isProximityMonitoringEnabled = true

        NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in self?.updateDynamicInfo() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in self?.updateDynamicInfo() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in self?.updateDynamicInfo() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIDevice.proximityStateDidChangeNotification)
            .sink { [weak self] _ in self?.updateDynamicInfo() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIScreen.brightnessDidChangeNotification)
            .sink { [weak self] _ in
                self?.currentBrightness = UIScreen.main.brightness
            }
            .store(in: &cancellables)

        pollingCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateDynamicInfo() }

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refreshWiFiInfo() }
            .store(in: &cancellables)

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateNetworkInfo(path)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
        self.monitor = monitor

        startMotionUpdates()
        startBarometerUpdates()
        startMotionActivityUpdates()
        startLocationUpdates()
        updateDynamicInfo()
        refreshSensors()
    }

    // MARK: - 运动传感器（CMMotionManager）
    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] _, _ in
                self?.refreshSensors()
            }
        }
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] _, _ in
                self?.refreshSensors()
            }
        }
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { [weak self] _, _ in
                self?.refreshSensors()
            }
        }
        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.startMagnetometerUpdates(to: .main) { [weak self] _, _ in
                self?.refreshSensors()
            }
        }
    }

    // MARK: - 气压计（CMAltimeter）
    private func startBarometerUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            self?.lastBarometer = data
            self?.refreshSensors()
        }
    }

    // MARK: - 运动状态（CMMotionActivityManager，需 Motion & Fitness 权限）
    private func startMotionActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            lastActivity = nil
            return
        }
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            self?.lastActivity = activity
            self?.refreshSensors()
        }
    }

    // MARK: - 定位（CLLocationManagerDelegate）
    private func startLocationUpdates() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        refreshSensors()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errors.append(String(localized: "Location failed: \(error.localizedDescription)"))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.startUpdatingLocation()
        }
        refreshSensors()
    }

    // MARK: - 传感器/定位数据刷新
    private func refreshSensors() {
        let motion = motionManager.deviceMotion
        let baro = lastBarometer
        let activity = lastActivity
        let location = lastLocation
        let status = locationManager.authorizationStatus

        sensorInfo = SensorInfo(
            isAccelerometerAvailable: motionManager.isAccelerometerAvailable,
            isGyroAvailable: motionManager.isGyroAvailable,
            isMagnetometerAvailable: motionManager.isMagnetometerAvailable,
            isDeviceMotionAvailable: motionManager.isDeviceMotionAvailable,
            isBarometerAvailable: CMAltimeter.isRelativeAltitudeAvailable(),
            accelerometerText: vectorText(motionManager.accelerometerData?.acceleration.x,
                                          motionManager.accelerometerData?.acceleration.y,
                                          motionManager.accelerometerData?.acceleration.z),
            gyroText: vectorText(motionManager.gyroData?.rotationRate.x,
                                 motionManager.gyroData?.rotationRate.y,
                                 motionManager.gyroData?.rotationRate.z),
            magnetometerText: vectorText(motionManager.magnetometerData?.magneticField.x,
                                         motionManager.magnetometerData?.magneticField.y,
                                         motionManager.magnetometerData?.magneticField.z),
            userAccelerationText: vectorText(motion?.userAcceleration.x, motion?.userAcceleration.y, motion?.userAcceleration.z),
            rotationRateText: vectorText(motion?.rotationRate.x, motion?.rotationRate.y, motion?.rotationRate.z),
            attitudeText: attitudeText(motion?.attitude),
            relativeAltitudeText: baro.map { String(format: "%.2f m", $0.relativeAltitude.doubleValue) } ?? String(localized: "Unavailable"),
            pressureText: baro.map { String(format: "%.2f kPa", $0.pressure.doubleValue) } ?? String(localized: "Unavailable"),
            motionActivityText: motionActivityText(activity),
            latitudeText: location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? String(localized: "Unavailable"),
            longitudeText: location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? String(localized: "Unavailable"),
            altitudeText: location.map { String(format: "%.1f m", $0.altitude) } ?? String(localized: "Unavailable"),
            courseText: location.map { String(format: "%.0f°", $0.course) } ?? String(localized: "Unavailable"),
            speedText: location.map { String(format: "%.1f m/s", $0.speed) } ?? String(localized: "Unavailable"),
            horizontalAccuracyText: location.map { String(format: "±%.0f m", $0.horizontalAccuracy) } ?? String(localized: "Unavailable"),
            locationAuthStatus: locationAuthString(status),
            accuracyAuthorizationText: accuracyAuthString(locationManager.accuracyAuthorization)
        )
    }

    // MARK: - 动态信息监听
    private func updateDynamicInfo() {
        currentOrientation = orientationString(device.orientation)
        batteryLevel = device.batteryLevel
        batteryState = batteryStateString(device.batteryState)
        proximityState = device.proximityState
        thermalState = thermalString(ProcessInfo.processInfo.thermalState)
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        currentBrightness = UIScreen.main.brightness
    }

    private func stopMonitoring() {
        device.endGeneratingDeviceOrientationNotifications()
        device.isBatteryMonitoringEnabled = false
        device.isProximityMonitoringEnabled = false
        monitor?.cancel()
        pollingCancellable?.cancel()
        cancellables.removeAll()
        if motionManager.isDeviceMotionActive { motionManager.stopDeviceMotionUpdates() }
        if motionManager.isAccelerometerActive { motionManager.stopAccelerometerUpdates() }
        if motionManager.isGyroActive { motionManager.stopGyroUpdates() }
        if motionManager.isMagnetometerActive { motionManager.stopMagnetometerUpdates() }
        altimeter.stopRelativeAltitudeUpdates()
        motionActivityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 辅助工具

    static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec))
    }

    static func sysctlUInt64(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }

    static func sysctlInt32(_ name: String) -> Int32 {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // 总 CPU 使用率（host_cpu_load_info）
    static func cpuUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return (user + system + nice) / total * 100
    }

    // 本进程内存（task_basic_info）
    static func taskMemory() -> (resident: UInt64, virtual: UInt64) {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        return (UInt64(info.resident_size), UInt64(info.virtual_size))
    }

    // 本机 IPv4 地址（en0 WiFi / pdp_ip0 蜂窝）
    static func localIPAddress() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return String(localized: "Unknown") }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let p = ptr {
            let family = p.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET), (p.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 {
                let name = String(cString: p.pointee.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        p.pointee.ifa_addr,
                        socklen_t(p.pointee.ifa_addr.pointee.sa_len),
                        &host,
                        socklen_t(host.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0 {
                        return String(cString: host)
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }
        return String(localized: "Unknown")
    }

    // 全部 IPv4 接口（含 lo0）
    static func interfaceList() -> String {
        var lines: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return String(localized: "Unknown") }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let p = ptr {
            let family = p.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: p.pointee.ifa_name)
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    p.pointee.ifa_addr,
                    socklen_t(p.pointee.ifa_addr.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    lines.append("\(name): \(String(cString: host))")
                }
            }
            ptr = p.pointee.ifa_next
        }
        return lines.isEmpty ? String(localized: "None") : lines.joined(separator: "\n")
    }

    // DNS 服务器（libresolv，经 BridgingHeader 暴露；Apple 平台符号带 res_9_ 前缀）
    static func dnsServers() -> String {
        let state = res_9_state.allocate(capacity: 1)
        memset(state, 0, MemoryLayout<res_9_state.Pointee>.size)
        guard res_9_ninit(state) == 0 else {
            state.deallocate()
            return String(localized: "Unknown")
        }
        defer {
            res_9_nclose(state)
            state.deallocate()
        }

        var servers = [res_9_sockaddr_union](repeating: res_9_sockaddr_union(sin: sockaddr_in()), count: 8)
        let count = servers.withUnsafeMutableBufferPointer { buffer -> Int32 in
            res_9_getservers(state, buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return String(localized: "None") }

        var result: [String] = []
        for index in 0..<Int(count) {
            var server = servers[index]
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            if let address = inet_ntop(AF_INET, &server.sin.sin_addr, &buffer, socklen_t(buffer.count)) {
                result.append(String(cString: address))
            }
        }
        return result.isEmpty ? String(localized: "None") : result.joined(separator: ", ")
    }

    // 越狱检测（文件标记法）
    static func jailbreakDetection() -> (isJailbroken: Bool, markers: String) {
        let markers = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/usr/libexec/ssh-keysign",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/stash",
            "/var/lib/cydia",
            "/usr/lib/cydia",
            "/.installed_unc0ver",
            "/.bootstrapped_electra",
        ]
        let found = markers.filter { FileManager.default.fileExists(atPath: $0) }
        return (found.isEmpty ? false : true, found.joined(separator: ", "))
    }

    // hw.machine 标识 → 机型名（未收录的返回原始标识）
    static func friendlyDeviceName(_ identifier: String) -> String {
        let map: [String: String] = [
            "iPhone9,1": "iPhone 7", "iPhone9,2": "iPhone 7 Plus",
            "iPhone9,3": "iPhone 7", "iPhone9,4": "iPhone 7 Plus",
            "iPhone10,1": "iPhone 8", "iPhone10,2": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X", "iPhone10,4": "iPhone 8", "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,8": "iPhone SE (2nd gen)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone 17 Air", "iPhone18,5": "iPhone 17e",
            "iPad5,1": "iPad mini 4", "iPad5,4": "iPad Air 2",
            "iPad6,4": "iPad Pro 9.7\"", "iPad6,8": "iPad Pro 12.9\" (1st gen)",
            "iPad6,12": "iPad (5th gen)",
            "iPad7,1": "iPad Pro 12.9\" (2nd gen)", "iPad7,3": "iPad Pro 10.5\"",
            "iPad7,6": "iPad (6th gen)", "iPad7,12": "iPad (7th gen)",
            "iPad8,1": "iPad Pro 11\" (1st gen)", "iPad8,5": "iPad Pro 12.9\" (3rd gen)",
            "iPad8,9": "iPad Pro 11\" (2nd gen)", "iPad8,12": "iPad Pro 12.9\" (4th gen)",
            "iPad11,1": "iPad mini (5th gen)", "iPad11,3": "iPad Air (3rd gen)",
            "iPad11,6": "iPad (8th gen)", "iPad11,7": "iPad (8th gen)",
            "iPad12,2": "iPad (9th gen)",
            "iPad13,1": "iPad Air (4th gen)", "iPad13,2": "iPad Air (4th gen)",
            "iPad13,4": "iPad Pro 11\" (3rd gen)", "iPad13,5": "iPad Pro 11\" (3rd gen)",
            "iPad13,8": "iPad Pro 12.9\" (5th gen)", "iPad13,10": "iPad Pro 12.9\" (5th gen)",
            "iPad13,16": "iPad Air (5th gen)", "iPad13,17": "iPad Air (5th gen)",
            "iPad13,18": "iPad (10th gen)",
            "iPad14,1": "iPad mini (6th gen)", "iPad14,2": "iPad mini (6th gen)",
            "iPad14,3": "iPad Pro 11\" (4th gen)", "iPad14,4": "iPad Pro 11\" (4th gen)",
            "iPad14,5": "iPad Pro 12.9\" (6th gen)",
            "iPad14,8": "iPad Air 11\" (M2)", "iPad14,9": "iPad Air 11\" (M2)",
            "iPad14,10": "iPad Air 13\" (M2)", "iPad14,11": "iPad Air 13\" (M2)",
            "iPad15,3": "iPad Air 11\" (M3)", "iPad15,4": "iPad Air 11\" (M3)",
            "iPad15,5": "iPad Air 13\" (M3)", "iPad15,6": "iPad Air 13\" (M3)",
            "iPad15,7": "iPad (A16)",
            "iPad16,2": "iPad mini (A17 Pro)",
            "iPad16,4": "iPad Pro 11\" (M4)", "iPad16,6": "iPad Pro 13\" (M4)",
            "iPad16,9": "iPad Air 11\" (M4)", "iPad16,11": "iPad Air 13\" (M4)",
            "iPad17,2": "iPad Pro 11\" (M5)", "iPad17,4": "iPad Pro 13\" (M5)",
        ]
        return map[identifier] ?? identifier
    }

    // CPU 品牌：machdep.cpu.brand_string 仅 Intel 平台有值，Apple 芯片返回空
    static func cpuBrand() -> String {
        let brand = sysctlString("machdep.cpu.brand_string")
        return brand.isEmpty ? "Apple Silicon" : brand
    }

    // 屏幕对角线（英寸）：系统不暴露物理尺寸，只能按机型查表
    static func screenDiagonal(_ identifier: String) -> String? {
        let map: [String: String] = [
            "iPhone8,1": "4.7\"", "iPhone8,2": "5.5\"", "iPhone8,4": "4.0\"",
            "iPhone9,1": "4.7\"", "iPhone9,2": "5.5\"", "iPhone9,3": "4.7\"", "iPhone9,4": "5.5\"",
            "iPhone10,1": "4.7\"", "iPhone10,2": "5.5\"", "iPhone10,3": "5.8\"",
            "iPhone10,4": "4.7\"", "iPhone10,5": "5.5\"", "iPhone10,6": "5.8\"",
            "iPhone11,2": "5.8\"", "iPhone11,4": "6.5\"", "iPhone11,6": "6.5\"", "iPhone11,8": "6.1\"",
            "iPhone12,1": "6.1\"", "iPhone12,3": "5.8\"", "iPhone12,5": "6.5\"", "iPhone12,8": "4.7\"",
            "iPhone13,1": "5.4\"", "iPhone13,2": "6.1\"", "iPhone13,3": "6.1\"", "iPhone13,4": "6.7\"",
            "iPhone14,2": "6.1\"", "iPhone14,3": "6.7\"", "iPhone14,4": "5.4\"", "iPhone14,5": "6.1\"",
            "iPhone14,6": "4.7\"", "iPhone14,7": "6.1\"", "iPhone14,8": "6.7\"",
            "iPhone15,2": "6.1\"", "iPhone15,3": "6.7\"", "iPhone15,4": "6.1\"", "iPhone15,5": "6.7\"",
            "iPhone16,1": "6.1\"", "iPhone16,2": "6.7\"",
            "iPhone17,1": "6.3\"", "iPhone17,2": "6.9\"", "iPhone17,3": "6.1\"", "iPhone17,4": "6.7\"", "iPhone17,5": "6.1\"",
            "iPhone18,1": "6.3\"", "iPhone18,2": "6.9\"", "iPhone18,3": "6.3\"", "iPhone18,4": "6.5\"", "iPhone18,5": "6.1\"",
            "iPad5,1": "7.9\"", "iPad5,4": "9.7\"",
            "iPad6,4": "9.7\"", "iPad6,8": "12.9\"", "iPad6,12": "9.7\"",
            "iPad7,1": "12.9\"", "iPad7,3": "10.5\"", "iPad7,6": "9.7\"", "iPad7,12": "10.2\"",
            "iPad8,1": "11\"", "iPad8,5": "12.9\"", "iPad8,9": "11\"", "iPad8,12": "12.9\"",
            "iPad11,1": "7.9\"", "iPad11,3": "10.5\"", "iPad11,6": "10.2\"", "iPad11,7": "10.2\"",
            "iPad12,2": "10.2\"",
            "iPad13,1": "10.9\"", "iPad13,2": "10.9\"",
            "iPad13,4": "11\"", "iPad13,5": "11\"",
            "iPad13,8": "12.9\"", "iPad13,10": "12.9\"",
            "iPad13,16": "10.9\"", "iPad13,17": "10.9\"", "iPad13,18": "10.9\"",
            "iPad14,1": "8.3\"", "iPad14,2": "8.3\"",
            "iPad14,3": "11\"", "iPad14,4": "11\"", "iPad14,5": "12.9\"",
            "iPad14,8": "11\"", "iPad14,9": "11\"", "iPad14,10": "13\"", "iPad14,11": "13\"",
            "iPad15,3": "11\"", "iPad15,4": "11\"", "iPad15,5": "13\"", "iPad15,6": "13\"",
            "iPad16,2": "8.3\"", "iPad16,4": "11\"", "iPad16,6": "13\"",
            "iPad16,9": "11\"", "iPad16,11": "13\"",
            "iPad17,2": "11\"", "iPad17,4": "13\"",
        ]
        return map[identifier]
    }

    // 生物识别能力（Face ID / Touch ID / Optic ID）
    static func biometricString() -> String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return String(localized: "Unavailable")
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return String(localized: "None")
        @unknown default: return String(localized: "Unknown")
        }
    }

    // 设备是否设置了密码/生物识别（无需弹窗，仅查询）
    static func passcodeSet() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // 通知授权状态（异步）
    func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor [weak self] in
                self?.notificationAuthStatus = Self.notificationStatusString(settings.authorizationStatus)
            }
        }
    }

    static func notificationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return String(localized: "Not Determined")
        case .denied: return String(localized: "Denied")
        case .authorized: return String(localized: "Authorized")
        case .provisional: return String(localized: "Provisional")
        case .ephemeral: return String(localized: "Ephemeral")
        @unknown default: return String(localized: "Unknown")
        }
    }

    static func byteString(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.2f %@", value, units[index])
    }

    private func idiomString(_ idiom: UIUserInterfaceIdiom) -> String {
        switch idiom {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        case .mac: return "Mac"
        case .tv: return "Apple TV"
        case .carPlay: return "CarPlay"
        case .vision: return "Vision Pro"
        default: return String(localized: "Unknown")
        }
    }

    private func sizeClassString(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: return String(localized: "Compact")
        case .regular: return String(localized: "Regular")
        case .unspecified: return String(localized: "Unspecified")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func backgroundRefreshString(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available: return String(localized: "Available")
        case .denied: return String(localized: "Denied")
        case .restricted: return String(localized: "Restricted")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func calendarString(_ identifier: Calendar.Identifier) -> String {
        switch identifier {
        case .gregorian: return String(localized: "Gregorian")
        case .chinese: return String(localized: "Chinese")
        case .iso8601: return "ISO 8601"
        case .japanese: return String(localized: "Japanese")
        case .buddhist: return String(localized: "Buddhist")
        case .islamic: return String(localized: "Islamic")
        case .islamicCivil: return String(localized: "Islamic Civil")
        case .hebrew: return String(localized: "Hebrew")
        case .coptic: return String(localized: "Coptic")
        case .ethiopicAmeteMihret: return String(localized: "Ethiopian (AmeteMihret)")
        case .ethiopicAmeteAlem: return String(localized: "Ethiopian (AmeteAlem)")
        case .indian: return String(localized: "Indian")
        case .persian: return String(localized: "Persian")
        case .republicOfChina: return String(localized: "Republic of China")
        case .islamicTabular: return String(localized: "Islamic Tabular")
        case .islamicUmmAlQura: return String(localized: "Islamic Umm al-Qura")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func orientationString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .unknown: return String(localized: "Unknown")
        case .portrait: return String(localized: "Portrait (Upright)")
        case .portraitUpsideDown: return String(localized: "Portrait (Upside Down)")
        case .landscapeLeft: return String(localized: "Landscape (Left)")
        case .landscapeRight: return String(localized: "Landscape (Right)")
        case .faceUp: return String(localized: "Face Up")
        case .faceDown: return String(localized: "Face Down")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return String(localized: "Unknown")
        case .unplugged: return String(localized: "Unplugged")
        case .charging: return String(localized: "Charging")
        case .full: return String(localized: "Full")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func thermalString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return String(localized: "Normal")
        case .fair: return String(localized: "Fair")
        case .serious: return String(localized: "Serious")
        case .critical: return String(localized: "Critical")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return String(localized: "Active")
        case .inactive: return String(localized: "Inactive")
        case .background: return String(localized: "Background")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func radioTechString(_ tech: String?) -> String {
        guard let tech = tech else { return String(localized: "Unknown") }
        switch tech {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
            return "2G"
        case CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB:
            return "3G"
        case CTRadioAccessTechnologyLTE:
            return "4G LTE"
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
            return "5G"
        default:
            return tech
        }
    }

    private func vectorText(_ x: Double?, _ y: Double?, _ z: Double?) -> String {
        guard let x = x, let y = y, let z = z else { return String(localized: "Unavailable") }
        return String(format: "x: %.2f  y: %.2f  z: %.2f", x, y, z)
    }

    private func attitudeText(_ attitude: CMAttitude?) -> String {
        guard let attitude = attitude else { return String(localized: "Unavailable") }
        let toDegrees = 180.0 / Double.pi
        return String(format: "pitch: %.1f°  roll: %.1f°  yaw: %.1f°",
                      attitude.pitch * toDegrees, attitude.roll * toDegrees, attitude.yaw * toDegrees)
    }

    private func motionActivityText(_ activity: CMMotionActivity?) -> String {
        guard let activity = activity else { return String(localized: "Unavailable (Motion & Fitness permission needed)") }
        var labels: [String] = []
        if activity.stationary { labels.append(String(localized: "Stationary")) }
        if activity.walking { labels.append(String(localized: "Walking")) }
        if activity.running { labels.append(String(localized: "Running")) }
        if activity.automotive { labels.append(String(localized: "Driving")) }
        if activity.cycling { labels.append(String(localized: "Cycling")) }
        if activity.unknown { labels.append(String(localized: "Unknown")) }
        let confidence = activity.confidence
        let confidenceLabel = confidence == .high
            ? String(localized: "High")
            : (confidence == .medium ? String(localized: "Medium") : String(localized: "Low"))
        return labels.isEmpty
            ? String(localized: "Unknown")
            : String(localized: "\(labels.joined(separator: " / ")) (confidence: \(confidenceLabel))")
    }

    private func locationAuthString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return String(localized: "Not Determined")
        case .authorizedWhenInUse: return String(localized: "While Using")
        case .authorizedAlways: return String(localized: "Always")
        case .denied: return String(localized: "Denied")
        case .restricted: return String(localized: "Restricted")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func mediaAuthString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return String(localized: "Authorized")
        case .denied: return String(localized: "Denied")
        case .notDetermined: return String(localized: "Not Determined")
        case .restricted: return String(localized: "Restricted")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func nextDSTString() -> String {
        guard let next = TimeZone.current.nextDaylightSavingTimeTransition else {
            return String(localized: "None (this time zone has no DST)")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: next)
    }

    private func audioRecordPermissionString(_ permission: AVAudioSession.RecordPermission) -> String {
        switch permission {
        case .undetermined: return String(localized: "Not Determined")
        case .granted: return String(localized: "Authorized")
        case .denied: return String(localized: "Denied")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private func accuracyAuthString(_ accuracy: CLAccuracyAuthorization) -> String {
        switch accuracy {
        case .fullAccuracy: return String(localized: "Full Accuracy")
        case .reducedAccuracy: return String(localized: "Reduced Accuracy")
        @unknown default: return String(localized: "Unknown")
        }
    }
}
