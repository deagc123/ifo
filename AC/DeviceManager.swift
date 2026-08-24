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
import AdSupport
import AppTrackingTransparency
import Metal
import LocalAuthentication
import CoreNFC
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

    // MARK: - 已安装 App
    @Published var installedApps: [InstalledApp] = []

    // MARK: - 动态信息（单独 @Published，不走 struct）
    @Published var currentOrientation = ""
    @Published var batteryLevel: Float = -1
    @Published var batteryState = ""
    @Published var proximityState = false
    @Published var thermalState = ""
    @Published var lowPowerMode = false
    @Published var currentBrightness: CGFloat = 0
    @Published var currentConnectionType = "未知"

    // MARK: - 网络细节（单独 @Published，异步/一次计算）
    @Published var networkInterfaces = "未知"
    @Published var dnsServers = "未知"
    @Published var externalIPAddress = "未知"

    // MARK: - 广告标识与推送（异步）
    @Published var idfa = "未知"
    @Published var idfaAuthStatus = "未请求"
    @Published var pushToken = "未知"
    @Published var pushStatus = "未注册"
    @Published var notificationAuthStatus = "未知"

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

    // MARK: - scheme 目录（需与 Info.plist 的 LSApplicationQueriesSchemes 一致）
    private static let schemeCatalog: [(name: String, scheme: String, icon: String)] = [
        ("微信", "weixin", "message.fill"),
        ("QQ", "mqq", "bubble.left.and.bubble.right.fill"),
        ("支付宝", "alipay", "creditcard.fill"),
        ("淘宝", "taobao", "bag.fill"),
        ("京东", "openapp.jdmobile", "cart.fill"),
        ("抖音", "snssdk1128", "play.rectangle.fill"),
        ("微博", "sinaweibo", "at"),
        ("哔哩哔哩", "bilibili", "tv.fill"),
        ("美团", "imeituan", "fork.knife"),
        ("高德地图", "iosamap", "map.fill"),
    ]

    override init() {
        super.init()
        locationManager.delegate = self
        requestLocationAuthorization()
        startMonitoring()
        refreshAll()
        requestIDFA()
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
        refreshInstalledApps()
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
            identifierForVendor: device.identifierForVendor?.uuidString ?? "无",
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
            cpuBrandString: DeviceManager.sysctlString("machdep.cpu.brand_string"),
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
            simulatorDeviceName: p.environment["SIMULATOR_DEVICE_NAME"] ?? "非模拟器",
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
            gpuName: metalDevice?.name ?? "无",
            gpuWorkingSet: metalDevice?.recommendedMaxWorkingSetSize ?? 0,
            gpuMaxThreadsPerGroup: Int(metalDevice?.maxThreadsPerThreadgroup.width ?? 0),
            maxRefreshRate: Int(UIScreen.main.maximumFramesPerSecond),
            safeAreaTop: safeTop,
            safeAreaBottom: safeBottom,
            isMultitaskingSupported: device.isMultitaskingSupported,
            biometricType: Self.biometricString(),
            hasPasscode: Self.passcodeSet(),
            nfcSupported: Self.nfcAvailable()
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
            errors.append("获取内存信息失败")
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
            errors.append("获取磁盘信息失败: \(error.localizedDescription)")
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
        var connectionType = "未知"
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wifi) {
                connectionType = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                connectionType = "蜂窝网络"
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = "有线网络"
            } else {
                connectionType = "其他网络"
            }
        case .unsatisfied:
            connectionType = "无网络"
        case .requiresConnection:
            connectionType = "需建立连接"
        @unknown default:
            connectionType = "未知"
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
            externalIPAddress = "获取失败（所有源均不可达）"
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
            applySSID("未获取（需授权定位）", bssid: "")
            return
        }
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let network = network, !network.ssid.isEmpty {
                    self.applySSID(network.ssid, bssid: network.bssid)
                } else {
                    self.applySSID("未获取（未连接WiFi或受限）", bssid: "")
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

        var displayGamut = "其他"
        if traits.displayGamut == .P3 {
            displayGamut = "P3 广色域"
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
            accessibilityContrast: traits.accessibilityContrast == .high ? "高对比度" : "标准",
            audioRoute: route,
            outputVolume: session.outputVolume,
            audioSampleRate: session.sampleRate,
            calendarIdentifier: calendarIdentifier,
            firstWeekday: weekday,
            usesMetricSystem: UserDefaults.standard.bool(forKey: "AppleMetricUnits"),
            temperatureUnit: UserDefaults.standard.string(forKey: "AppleTemperatureUnit") ?? "未知",
            timeZoneAbbreviation: TimeZone.current.abbreviation() ?? "未知",
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
            keyboards: keyboards.isEmpty ? "无" : keyboards.joined(separator: "、"),
            timeZoneLocalizedName: TimeZone.current.localizedName(for: .shortGeneric, locale: .current) ?? "未知",
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
            name = first.carrierName ?? "未知"
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

    // MARK: - 已安装 App（canOpenURL 探测）
    private func refreshInstalledApps() {
        installedApps = Self.schemeCatalog.map { item in
            let installed = URL(string: "\(item.scheme)://")
                .map { UIApplication.shared.canOpenURL($0) } ?? false
            return InstalledApp(
                name: item.name,
                scheme: item.scheme,
                isInstalled: installed,
                iconName: item.icon
            )
        }
    }

    // MARK: - 唤起 App
    func openApp(_ app: InstalledApp) {
        guard let url = URL(string: app.urlString) else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                print("打开失败: \(app.scheme)")
            }
        }
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
        UIApplication.shared.registerForRemoteNotifications()

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
        errors.append("定位失败: \(error.localizedDescription)")
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
            relativeAltitudeText: baro.map { String(format: "%.2f m", $0.relativeAltitude.doubleValue) } ?? "未获取",
            pressureText: baro.map { String(format: "%.2f kPa", $0.pressure.doubleValue) } ?? "未获取",
            motionActivityText: motionActivityText(activity),
            latitudeText: location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "未获取",
            longitudeText: location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "未获取",
            altitudeText: location.map { String(format: "%.1f m", $0.altitude) } ?? "未获取",
            courseText: location.map { String(format: "%.0f°", $0.course) } ?? "未获取",
            speedText: location.map { String(format: "%.1f m/s", $0.speed) } ?? "未获取",
            horizontalAccuracyText: location.map { String(format: "±%.0f m", $0.horizontalAccuracy) } ?? "未获取",
            locationAuthStatus: locationAuthString(status),
            accuracyAuthorizationText: accuracyAuthString(locationManager.accuracyAuthorization)
        )
    }

    // MARK: - 广告标识（IDFA）
    private func requestIDFA() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            refreshIDFA()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshIDFA()
            }
        }
    }

    private func refreshIDFA() {
        idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        idfaAuthStatus = trackingAuthString(ATTrackingManager.trackingAuthorizationStatus)
    }

    // MARK: - 推送令牌（由 AppDelegate 回调）
    func updatePushToken(_ token: Data) {
        pushToken = token.map { String(format: "%02x", $0) }.joined()
        pushStatus = "已注册"
    }

    func updatePushError(_ error: Error) {
        pushStatus = "注册失败（\(error.localizedDescription)）"
        pushToken = "无"
    }

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
        guard getifaddrs(&ifaddr) == 0 else { return "未知" }
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
        return "未知"
    }

    // 全部 IPv4 接口（含 lo0）
    static func interfaceList() -> String {
        var lines: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "未知" }
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
        return lines.isEmpty ? "无" : lines.joined(separator: "\n")
    }

    // DNS 服务器（libresolv，经 BridgingHeader 暴露；Apple 平台符号带 res_9_ 前缀）
    static func dnsServers() -> String {
        let state = res_9_state.allocate(capacity: 1)
        memset(state, 0, MemoryLayout<res_9_state.Pointee>.size)
        guard res_9_ninit(state) == 0 else {
            state.deallocate()
            return "未知"
        }
        defer {
            res_9_nclose(state)
            state.deallocate()
        }

        var servers = [res_9_sockaddr_union](repeating: res_9_sockaddr_union(sin: sockaddr_in()), count: 8)
        let count = servers.withUnsafeMutableBufferPointer { buffer -> Int32 in
            res_9_getservers(state, buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return "无" }

        var result: [String] = []
        for index in 0..<Int(count) {
            var server = servers[index]
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            if let address = inet_ntop(AF_INET, &server.sin.sin_addr, &buffer, socklen_t(buffer.count)) {
                result.append(String(cString: address))
            }
        }
        return result.isEmpty ? "无" : result.joined(separator: ", ")
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
            "iPhone12,8": "iPhone SE (2代)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17", "iPhone18,2": "iPhone 17 Pro",
            "iPhone18,3": "iPhone 17 Pro Max", "iPhone18,4": "iPhone 17 Air",
            "iPad8,1": "iPad Pro 11\" (2代)", "iPad8,9": "iPad Pro 11\" (3代)",
            "iPad11,1": "iPad mini (5代)", "iPad11,3": "iPad Air (3代)",
            "iPad13,1": "iPad Air (4代)", "iPad13,4": "iPad Pro 11\" (3代)",
            "iPad13,8": "iPad Pro 12.9\" (5代)", "iPad13,16": "iPad Pro 11\" (4代)",
            "iPad13,18": "iPad Pro 12.9\" (6代)", "iPad14,1": "iPad mini (6代)",
            "iPad14,8": "iPad Pro 11\" (M4)", "iPad14,10": "iPad Pro 13\" (M4)",
            "iPad15,3": "iPad Air 11\" (M2)", "iPad15,8": "iPad Pro 11\" (M4)",
        ]
        return map[identifier] ?? identifier
    }

    // 生物识别能力（Face ID / Touch ID / Optic ID）
    static func biometricString() -> String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return "不可用"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "无"
        @unknown default: return "未知"
        }
    }

    // 设备是否设置了密码/生物识别（无需弹窗，仅查询）
    static func passcodeSet() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // NFC 读取能力
    static func nfcAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCNDEFReaderSession.readingAvailable
        #endif
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
        case .notDetermined: return "未决定"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        case .provisional: return "临时授权"
        case .ephemeral: return "短暂授权"
        @unknown default: return "未知"
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
        default: return "未知"
        }
    }

    private func sizeClassString(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: return "紧凑 (compact)"
        case .regular: return "常规 (regular)"
        case .unspecified: return "未指定"
        @unknown default: return "未知"
        }
    }

    private func backgroundRefreshString(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available: return "已启用"
        case .denied: return "已禁用"
        case .restricted: return "受限"
        @unknown default: return "未知"
        }
    }

    private func calendarString(_ identifier: Calendar.Identifier) -> String {
        switch identifier {
        case .gregorian: return "公历 (gregorian)"
        case .chinese: return "中国农历"
        case .iso8601: return "ISO 8601"
        case .japanese: return "日本和历"
        case .buddhist: return "佛历"
        case .islamic: return "伊斯兰历"
        case .islamicCivil: return "伊斯兰民用历"
        case .hebrew: return "希伯来历"
        case .coptic: return "科普特历"
        case .ethiopicAmeteMihret: return "埃塞俄比亚历 (AmeteMihret)"
        case .ethiopicAmeteAlem: return "埃塞俄比亚历 (AmeteAlem)"
        case .indian: return "印度历"
        case .persian: return "波斯历"
        case .republicOfChina: return "中华民国历"
        case .islamicTabular: return "伊斯兰表格历"
        case .islamicUmmAlQura: return "伊斯兰乌姆库拉历"
        @unknown default: return "未知"
        }
    }

    private func orientationString(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .unknown: return "未知"
        case .portrait: return "竖屏（正面）"
        case .portraitUpsideDown: return "竖屏（倒置）"
        case .landscapeLeft: return "横屏（向左）"
        case .landscapeRight: return "横屏（向右）"
        case .faceUp: return "屏幕朝上"
        case .faceDown: return "屏幕朝下"
        @unknown default: return "未知"
        }
    }

    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "未知"
        case .unplugged: return "未充电"
        case .charging: return "充电中"
        case .full: return "已充满"
        @unknown default: return "未知"
        }
    }

    private func thermalString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "正常"
        case .fair: return "略热"
        case .serious: return "过热"
        case .critical: return "严重过热"
        @unknown default: return "未知"
        }
    }

    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }

    private func radioTechString(_ tech: String?) -> String {
        guard let tech = tech else { return "未知" }
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
        guard let x = x, let y = y, let z = z else { return "未获取" }
        return String(format: "x: %.2f  y: %.2f  z: %.2f", x, y, z)
    }

    private func attitudeText(_ attitude: CMAttitude?) -> String {
        guard let attitude = attitude else { return "未获取" }
        let toDegrees = 180.0 / Double.pi
        return String(format: "pitch: %.1f°  roll: %.1f°  yaw: %.1f°",
                      attitude.pitch * toDegrees, attitude.roll * toDegrees, attitude.yaw * toDegrees)
    }

    private func motionActivityText(_ activity: CMMotionActivity?) -> String {
        guard let activity = activity else { return "未获取（需运动与健身权限）" }
        var labels: [String] = []
        if activity.stationary { labels.append("静止") }
        if activity.walking { labels.append("步行") }
        if activity.running { labels.append("跑步") }
        if activity.automotive { labels.append("驾车") }
        if activity.cycling { labels.append("骑行") }
        if activity.unknown { labels.append("未知") }
        let confidence = activity.confidence
        let confidenceLabel = confidence == .high ? "高" : (confidence == .medium ? "中" : "低")
        return labels.isEmpty ? "未知" : "\(labels.joined(separator: " / "))（置信度\(confidenceLabel)）"
    }

    private func locationAuthString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未决定"
        case .authorizedWhenInUse: return "使用时允许"
        case .authorizedAlways: return "始终允许"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        @unknown default: return "未知"
        }
    }

    private func trackingAuthString(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未决定"
        case .restricted: return "受限"
        @unknown default: return "未知"
        }
    }

    private func mediaAuthString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未决定"
        case .restricted: return "受限"
        @unknown default: return "未知"
        }
    }

    private func nextDSTString() -> String {
        guard let next = TimeZone.current.nextDaylightSavingTimeTransition else {
            return "无（该时区不实行夏令时）"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: next)
    }

    private func audioRecordPermissionString(_ permission: AVAudioSession.RecordPermission) -> String {
        switch permission {
        case .undetermined: return "未决定"
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        @unknown default: return "未知"
        }
    }

    private func accuracyAuthString(_ accuracy: CLAccuracyAuthorization) -> String {
        switch accuracy {
        case .fullAccuracy: return "精确位置"
        case .reducedAccuracy: return "粗略位置"
        @unknown default: return "未知"
        }
    }
}
