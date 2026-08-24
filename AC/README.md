## 目录

- [1. 项目目标](#1-项目目标)
- [2. 总体架构与设计决策](#2-总体架构与设计决策)
- [3. 最终目录结构](#3-最终目录结构)
- [4. 数据模型（Models）](#4-数据模型models)
- [5. DeviceManager 核心类](#5-devicemanager-核心类)
- [6. 各数据源采集实现](#6-各数据源采集实现)
- [6.10 可检测的手机环境信息全景](#610-可检测的手机环境信息全景)
- [7. 动态信息监听机制](#7-动态信息监听机制)
- [8. 辅助工具方法（static）](#8-辅助工具方法static)
- [9. Info.plist 与 scheme 配置](#9-infoplist-与-scheme-配置)
- [10. SwiftUI 界面接线](#10-swiftui-界面接线)
- [11. 实施步骤清单](#11-实施步骤清单)
- [12. 注意事项与常见坑](#12-注意事项与常见坑)
- [13. API 信息源汇总表](#13-api-信息源汇总表)
- [14. App Store 审核清单](#14-app-store-审核清单)
- [15. 免责声明](#15-免责声明)

---

## 1. 项目目标

练习 iOS 获取设备信息与本地 App 安装情况，覆盖尽可能多的系统框架与 API。信息以「系统设置」风格（`List` + Section 分组）展示，并支持唤醒已安装的常用 App。

## 2. 总体架构与设计决策

### 2.1 架构总览

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Views (5 Tab)                │
│   只读 DeviceManager.shared，展示 @Published 数据          │
└────────────────────────┬────────────────────────────────┘
                         │ @ObservedObject
┌────────────────────────▼────────────────────────────────┐
│              DeviceManager (单例 ObservableObject)       │
│   负责：采集、存储、监听。持有 9 个 @Published 数据模型       │
│   + 若干 @Published 动态属性                              │
└────────────────────────┬────────────────────────────────┘
                         │ 赋值（整体替换 struct）
┌────────────────────────▼────────────────────────────────┐
│          9 个数据模型 struct（纯数据，只读快照）             │
│   DeviceInfo / SystemInfo / ScreenInfo / MemoryInfo      │
│   StorageInfo / NetworkInfo / CarrierInfo / BundleInfo   │
│   InstalledApp                                           │
└─────────────────────────────────────────────────────────┘
```

**核心思想**：数据模型是**值类型 struct**，`DeviceManager` 只负责"采集原始数据 → 构建新 struct → 整体赋值给 @Published"，View 拿到的始终是完整的、不可篡改的数据快照。

### 2.2 为什么用 struct 分组，而不是扁平 @Published 变量

| 维度 | 扁平 @Published 变量 | 按领域 struct 分组 |
| --- | --- | --- |
| **数据一致性** | 几十个变量逐个赋值，中途状态可能被 UI 读到 | `systemInfo = info` 一次整体替换，原子发布 |
| **代码组织** | 所有变量混在一起，刷新逻辑散落 | 8 个领域清晰对应 8 个 `refreshXXX()` |
| **格式化归属** | 格式化要么放 View、要么堆在 Manager 里一堆方法 | 放 struct 计算属性，Manager 只存原始值 |
| **测试/Preview** | 必须起真机 + Manager 实例才能测 | `SystemInfo(name:"测试", ...)` 直接构造喂给 View |
| **只读保护** | 字段都是 `var`，View 可随意改 | 字段声明 `private(set) var`，只有 Manager 能改 |
| **刷新粒度** | 无差异（`@Published` 变化都会触发 `objectWillChange`） | 无差异 |

> **诚实说明**：`@Published` 无论哪个属性变化都会触发 `objectWillChange`，`@ObservedObject` 的 View 只要读取对象任何属性就会整体重算 body。**分组 struct 在 SwiftUI 刷新粒度上没有优势**，价值在于组织性、一致性、可测性、只读保护。若信息量小，扁平变量也完全可用。

### 2.3 静态信息 vs 动态信息

| 类型 | 特点 | 存放位置 | 更新方式 |
| --- | --- | --- | --- |
| **静态信息**（型号、版本、运营商、磁盘容量…） | 一次性读取、基本不变 | struct 数据模型 | `refreshAll()` 时整体重建 |
| **动态信息**（方向、电量、接近、散热、低电量、亮度、连接类型） | 持续变化 | **单独 @Published 属性**（不走 struct） | 通知 / 轮询 / NWPathMonitor 回调 |

动态信息走独立 `@Published` 的原因：更新路径不同（通知/定时器/异步回调），且变化频繁，放进 struct 每次重建反而多余。

---

## 3. 最终目录结构

```
AC/
├── AC.xcodeproj                 # Xcode 工程
└── AC/
    ├── ACApp.swift              # App 入口，TabView 组织 5 个页面
    ├── DeviceManager.swift      # ★ 核心：单例采集与存储
    ├── BridgingHeader.h         # 桥接头（暴露 libresolv 的 DNS 函数）
    ├── Info.plist               # LSApplicationQueriesSchemes 声明
    ├── Assets.xcassets          # 资源目录
    ├── README.md                # 本文件
    ├── Models/
    │   └── DeviceModels.swift   # ★ 9 个数据模型 struct
    └── Views/
        ├── InfoRow.swift            # 通用信息行
        ├── DeviceInfoView.swift     # Tab1 设备信息页
        ├── SystemInfoView.swift     # Tab2 系统信息页
        ├── ScreenHardwareView.swift # Tab3 屏幕与硬件页
        ├── SensorView.swift         # Tab4 传感器页
        ├── BundleInfoView.swift     # Tab5 当前 App 页
        └── InstalledAppsView.swift  # Tab6 已安装 App 页
```

> 工程使用文件夹同步（`PBXFileSystemSynchronizedRootGroup`），在 `AC/` 目录下新建文件会自动加入编译，无需手动改工程文件。

---

## 4. 数据模型（Models）

文件：`AC/Models/DeviceModels.swift`。所有字段用 `private(set) var` 保证外部只读。

### 4.1 DeviceInfo（UIDevice + sysctl）

```swift
import UIKit

struct DeviceInfo {
    private(set) var name = ""
    private(set) var model = ""
    private(set) var localizedModel = ""
    private(set) var systemName = ""
    private(set) var systemVersion = ""
    private(set) var identifierForVendor = "无"
    private(set) var idiom = ""
    private(set) var hardwareModel = ""     // hw.machine，如 iPhone14,2
    private(set) var screenSize = ""
    private(set) var screenScale: CGFloat = 1.0
}
```

### 4.2 SystemInfo（ProcessInfo + sysctl + NSLocale + TimeZone）

```swift
import Foundation

struct SystemInfo {
    private(set) var uptime: TimeInterval = 0
    private(set) var osVersionString = ""
    private(set) var physicalMemory: UInt64 = 0
    private(set) var processorCount = 0
    private(set) var activeProcessorCount = 0
    private(set) var processorName = ""
    private(set) var thermalState = ""
    private(set) var lowPowerMode = false
    private(set) var hostName = ""
    private(set) var cpuBrandString = ""    // machdep.cpu.brand_string
    private(set) var kernOSVersion = ""     // kern.osversion
    private(set) var bootTime: Date?        // kern.boottime
    private(set) var preferredLanguages: [String] = []
    private(set) var localeIdentifier = ""
    private(set) var regionCode = ""
    private(set) var currencyCode = ""
    private(set) var timeZoneIdentifier = ""
    private(set) var secondsFromGMT = 0
    private(set) var isDaylightSaving = false

    // 格式化计算属性
    var uptimeText: String { "\(Int(uptime)) 秒" }
    var physicalMemoryText: String { DeviceManager.byteString(Int64(physicalMemory)) }
    var bootTimeText: String {
        guard let bootTime else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: bootTime)
    }
    var languageText: String { preferredLanguages.joined(separator: ", ") }
}
```

> 注意：计算属性里调用 `DeviceManager.byteString`，所以 Models 依赖 DeviceManager 的 static 方法。如果不想耦合，可把格式化工具做成独立的 `enum Formatter`，本文档为了简单直接复用 `DeviceManager` 的 static 方法。

### 4.3 ScreenInfo（UIScreen）

```swift
import UIKit

struct ScreenInfo {
    private(set) var bounds = ""            // 逻辑点尺寸
    private(set) var nativeBounds = ""      // 物理像素尺寸
    private(set) var scale: CGFloat = 1.0
    private(set) var nativeScale: CGFloat = 1.0
    private(set) var pixelSize = ""         // currentMode 像素尺寸
    private(set) var brightness: CGFloat = 0
    private(set) var maxBrightness: CGFloat = 1.0
    private(set) var displayName = ""       // 可能为空

    var scaleText: String { String(format: "%.1f", scale) }
    var nativeScaleText: String { String(format: "%.1f", nativeScale) }
}
```

### 4.4 MemoryInfo（Mach API）

```swift
import Foundation

struct MemoryInfo {
    private(set) var total: UInt64 = 0
    private(set) var free: UInt64 = 0
    private(set) var active: UInt64 = 0
    private(set) var inactive: UInt64 = 0
    private(set) var wired: UInt64 = 0

    var used: UInt64 { total - free }

    var totalText: String { DeviceManager.byteString(Int64(total)) }
    var usedText: String { DeviceManager.byteString(Int64(used)) }
    var freeText: String { DeviceManager.byteString(Int64(free)) }
    var activeText: String { DeviceManager.byteString(Int64(active)) }
    var inactiveText: String { DeviceManager.byteString(Int64(inactive)) }
    var wiredText: String { DeviceManager.byteString(Int64(wired)) }
}
```

### 4.5 StorageInfo（FileManager volume）

```swift
import Foundation

struct StorageInfo {
    private(set) var totalCapacity: Int64 = 0
    private(set) var availableForImportantUsage: Int64 = 0
    private(set) var availableForOpportunistic: Int64 = 0

    var totalText: String { DeviceManager.byteString(totalCapacity) }
    var availableText: String { DeviceManager.byteString(availableForImportantUsage) }
}
```

### 4.6 NetworkInfo（NWPathMonitor）

```swift
import Foundation

struct NetworkInfo {
    private(set) var connectionType = "未知"   // WiFi / 蜂窝网络 / 有线网络 / 无网络 / 需建立连接
    private(set) var isExpensive = false       // 是否计费网络
    private(set) var isConstrained = false     // 是否受限网络（低数据模式）
    private(set) var ssid = ""                 // WiFi 名称
    private(set) var bssid = ""                // WiFi MAC 地址
}
```

### 4.7 CarrierInfo（CoreTelephony）

```swift
import Foundation

struct CarrierInfo {
    private(set) var carrierName = ""
    private(set) var mobileCountryCode = ""    // MCC
    private(set) var mobileNetworkCode = ""    // MNC
    private(set) var isoCountryCode = ""
    private(set) var radioAccessTechnology = "" // 2G/3G/4G/5G
}
```

### 4.8 BundleInfo（Bundle.main + UIApplication + 沙盒）

```swift
import Foundation

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
```

### 4.9 InstalledApp（URL Scheme 探测）

```swift
import Foundation

struct InstalledApp: Identifiable {
    let id = UUID()
    private(set) var name: String
    private(set) var scheme: String
    private(set) var isInstalled = false
    private(set) var iconName: String        // SF Symbol 名称

    var urlString: String { "\(scheme)://" }
}
```

---

## 5. DeviceManager 核心类

文件：`AC/DeviceManager.swift`。

### 5.1 导入与单例

```swift
import Foundation
import UIKit
import Combine
import Network
import CoreTelephony
import MachO

class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    // MARK: 数据模型（静态信息快照）
    @Published var deviceInfo = DeviceInfo()
    @Published var systemInfo = SystemInfo()
    @Published var screenInfo = ScreenInfo()
    @Published var memoryInfo = MemoryInfo()
    @Published var storageInfo = StorageInfo()
    @Published var networkInfo = NetworkInfo()
    @Published var carrierInfo = CarrierInfo()
    @Published var bundleInfo = BundleInfo()

    // MARK: 已安装 App
    @Published var installedApps: [InstalledApp] = []

    // MARK: 动态信息（单独 @Published）
    @Published var currentOrientation = ""
    @Published var batteryLevel: Float = -1
    @Published var batteryState = ""
    @Published var proximityState = false
    @Published var thermalState = ""
    @Published var lowPowerMode = false
    @Published var currentBrightness: CGFloat = 0
    @Published var currentConnectionType = "未知"

    // MARK: 全局状态
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errors: [String] = []

    // MARK: 内部引用
    private let device = UIDevice.current
    private var monitor: NWPathMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var pollingCancellable: AnyCancellable?

    // MARK: scheme 目录（可探测的常用 App 清单）
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

    private init() {
        startMonitoring()
        refreshAll()
    }

    deinit {
        stopMonitoring()
    }
    // ... 以下方法
}
```

### 5.2 总刷新入口

```swift
func refreshAll() {
    isLoading = true
    refreshDeviceInfo()
    refreshSystemInfo()
    refreshScreenInfo()
    refreshMemoryInfo()
    refreshStorageInfo()
    refreshNetworkInfo()      // 用 monitor.currentPath 立即取一次当前状态
    refreshCarrierInfo()
    refreshBundleInfo()
    refreshInstalledApps()
    lastUpdated = Date()
    isLoading = false
}
```

> `refreshAll()` 是唯一对外刷新入口。各 `refreshXXX()` 全部 `private`，职责单一：**构建新 struct → 整体赋值**。任何一次刷新失败不中断其他模块，失败信息写入 `errors`。

---

## 6. 各数据源采集实现

### 6.1 refreshDeviceInfo（UIDevice + sysctl）

```swift
private func refreshDeviceInfo() {
    var info = DeviceInfo()
    info.name = device.name
    info.model = device.model
    info.localizedModel = device.localizedModel
    info.systemName = device.systemName
    info.systemVersion = device.systemVersion
    info.identifierForVendor = device.identifierForVendor?.uuidString ?? "无"
    info.idiom = idiomString(device.userInterfaceIdiom)
    info.hardwareModel = DeviceManager.sysctlString("hw.machine")
    let screen = UIScreen.main
    info.screenSize = "\(Int(screen.bounds.width)) x \(Int(screen.bounds.height))"
    info.screenScale = screen.scale
    deviceInfo = info
}
```

### 6.2 refreshSystemInfo（ProcessInfo + sysctl + NSLocale + TimeZone）

```swift
private func refreshSystemInfo() {
    let p = ProcessInfo.processInfo
    var info = SystemInfo()
    info.uptime = p.systemUptime
    info.osVersionString = p.operatingSystemVersionString
    info.physicalMemory = p.physicalMemory
    info.processorCount = p.processorCount
    info.activeProcessorCount = p.activeProcessorCount
    info.processorName = p.processorName
    info.thermalState = thermalString(p.thermalState)
    info.lowPowerMode = p.isLowPowerModeEnabled
    info.hostName = p.hostName
    info.cpuBrandString = DeviceManager.sysctlString("machdep.cpu.brand_string")
    info.kernOSVersion = DeviceManager.sysctlString("kern.osversion")
    info.bootTime = DeviceManager.bootTime()
    info.preferredLanguages = NSLocale.preferredLanguages
    info.localeIdentifier = NSLocale.current.identifier
    info.regionCode = NSLocale.current.regionCode ?? ""
    info.currencyCode = NSLocale.current.currencyCode ?? ""
    info.timeZoneIdentifier = TimeZone.current.identifier
    info.secondsFromGMT = TimeZone.current.secondsFromGMT()
    info.isDaylightSaving = TimeZone.current.isDaylightSavingTime()
    systemInfo = info
}
```

### 6.3 refreshScreenInfo（UIScreen）

```swift
private func refreshScreenInfo() {
    let s = UIScreen.main
    var info = ScreenInfo()
    info.bounds = "\(Int(s.bounds.width)) x \(Int(s.bounds.height))"
    info.nativeBounds = "\(Int(s.nativeBounds.width)) x \(Int(s.nativeBounds.height))"
    info.scale = s.scale
    info.nativeScale = s.nativeScale
    info.pixelSize = "\(Int(s.currentMode?.pixelWidth ?? 0)) x \(Int(s.currentMode?.pixelHeight ?? 0))"
    info.brightness = s.brightness
    if #available(iOS 17.0, *) {
        info.maxBrightness = s.maximumBrightness
    }
    screenInfo = info
}
```

> 注意：`UIScreen.maximumBrightness`、`UIScreenMode.pixelWidth` 在 iOS 上并不存在，编译会报 "no member"，实际代码使用 `currentMode.size` 获取像素尺寸。

### 6.4 refreshMemoryInfo（host_statistics64）

```swift
private func refreshMemoryInfo() {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(
        MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &stats) { p in
        p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        errors.append("获取内存信息失败")
        return
    }
    let pageSize = UInt64(vm_page_size)
    var info = MemoryInfo()
    info.total = ProcessInfo.processInfo.physicalMemory
    info.free = UInt64(stats.free_count) * pageSize
    info.active = UInt64(stats.active_count) * pageSize
    info.inactive = UInt64(stats.inactive_count) * pageSize
    info.wired = UInt64(stats.wire_count) * pageSize
    memoryInfo = info
}
```

> 原理：`host_statistics64` 返回的页面计数 × `vm_page_size` = 字节数。iOS 用 Memory Status 机制管理内存，`used = total - free` 是估算值。

### 6.5 refreshStorageInfo（FileManager volume）

```swift
private func refreshStorageInfo() {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    do {
        let values = try url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey,
        ])
        var info = StorageInfo()
        info.totalCapacity = Int64(values.volumeTotalCapacity ?? 0)
        info.availableForImportantUsage = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        info.availableForOpportunistic = Int64(values.volumeAvailableCapacityForOpportunisticUsage ?? 0)
        storageInfo = info
    } catch {
        errors.append("获取磁盘信息失败: \(error.localizedDescription)")
    }
}
```

### 6.6 refreshNetworkInfo / updateNetworkInfo（NWPathMonitor）

```swift
private func refreshNetworkInfo() {
    if let path = monitor?.currentPath {
        updateNetworkInfo(path)
    }
}

private func updateNetworkInfo(_ path: NWPath) {
    var info = NetworkInfo()
    switch path.status {
    case .satisfied:
        if path.usesInterfaceType(.wifi) {
            info.connectionType = "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            info.connectionType = "蜂窝网络"
        } else if path.usesInterfaceType(.wiredEthernet) {
            info.connectionType = "有线网络"
        } else {
            info.connectionType = "其他网络"
        }
    case .unsatisfied:
        info.connectionType = "无网络"
    case .requiresConnection:
        info.connectionType = "需建立连接"
    @unknown default:
        info.connectionType = "未知"
    }
    info.isExpensive = path.isExpensive
    info.isConstrained = path.isConstrained
    networkInfo = info
    currentConnectionType = info.connectionType
}
```

### 6.6.1 WiFi SSID 检测（NEHotspotNetwork）

除连接类型外，还能获取当前 WiFi 的 **SSID（名称）与 BSSID（MAC）**：

```swift
import NetworkExtension

NEHotspotNetwork.fetchCurrent { network in
    if let network = network, !network.ssid.isEmpty {
        print(network.ssid, network.bssid)
    } else {
        print("未获取到（需授权或未连接 WiFi）")
    }
}
```

**硬性要求**（缺一个都拿不到）：

1. **Entitlement**：`com.apple.developer.networking.wifi-info`（在 `.entitlements` 文件中声明，需在 Signing & Capabilities 里开启 "Access WiFi Information"）。**仅付费开发者账号可用**；免费账号启用会导致真机签名失败。
2. **定位权限**：`NSLocationWhenInUseUsageDescription` + 用户授权定位（iOS 13 起强制）。**App 必须主动调用 `CLLocationManager.requestWhenInUseAuthorization()`**，仅写 Info.plist 描述不够——未授权时 `fetchCurrent` 返回 `nil`。本工程在 `DeviceManager.init` 中请求，并在 `didBecomeActiveNotification` 时重新获取。
3. **真机**：模拟器上此 API 基本返回 `nil`，必须在真机上验证。

注意：iOS 16+ 出于隐私，BSSID 可能被混淆为全零。另一种旧 API 是 `CNCopyCurrentNetworkInfo`（SystemConfiguration），同样受以上限制。

### 6.7 refreshCarrierInfo（CoreTelephony）

```swift
private func refreshCarrierInfo() {
    let ct = CTTelephonyNetworkInfo()
    var info = CarrierInfo()
    if let providers = ct.serviceSubscriberCellularProviders,
       let first = providers.values.first {
        info.carrierName = first.carrierName ?? "未知"
        info.mobileCountryCode = first.mobileCountryCode ?? ""
        info.mobileNetworkCode = first.mobileNetworkCode ?? ""
        info.isoCountryCode = first.isoCountryCode ?? ""
    }
    info.radioAccessTechnology = radioTechString(ct.serviceCurrentRadioAccessTechnology)
    carrierInfo = info
}
```

### 6.8 refreshBundleInfo（Bundle.main + UIApplication + 沙盒）

```swift
private func refreshBundleInfo() {
    let bundle = Bundle.main
    var info = BundleInfo()
    info.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    info.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    info.bundleIdentifier = bundle.bundleIdentifier ?? ""
    info.displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
    info.bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    info.executable = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? ""
    info.minimumOSVersion = bundle.object(forInfoDictionaryKey: "MinimumOSVersion") as? String ?? ""
    info.sdkName = bundle.object(forInfoDictionaryKey: "DTSDKName") as? String ?? ""
    let fm = FileManager.default
    info.homeDirectory = NSHomeDirectory()
    info.documentsDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    info.cachesDirectory = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""
    info.tmpDirectory = NSTemporaryDirectory()
    info.applicationState = appStateString(UIApplication.shared.applicationState)
    info.backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
    bundleInfo = info
}
```

### 6.9 refreshInstalledApps（canOpenURL 探测）

```swift
private func refreshInstalledApps() {
    installedApps = Self.schemeCatalog.map { item in
        var app = InstalledApp(name: item.name, scheme: item.scheme, iconName: item.icon)
        if let url = URL(string: "\(item.scheme)://") {
            app.isInstalled = UIApplication.shared.canOpenURL(url)
        }
        return app
    }
}

// 对外动作：唤起 App
func openApp(_ app: InstalledApp) {
    guard let url = URL(string: app.urlString) else { return }
    UIApplication.shared.open(url, options: [:]) { success in
        if !success {
            print("打开失败: \(app.scheme)")
        }
    }
}
```

---

## 6.10 可检测的手机环境信息全景

工程当前已实现 + 未来可扩展的所有设备/环境信息来源，按类别划分：

### 已实现（本工程）

| 类别 | 内容 | API |
| --- | --- | --- |
| CPU | 使用率、频率、核数/线程、品牌 | `host_cpu_load_info`、`sysctl(hw.cpufrequency / machdep.cpu.*)` |
| 硬件详情 | 机型名映射、页大小、物理/逻辑核、封装数、CPU 细分、频率范围 | `sysctl(hw.pagesize / hw.physicalcpu / machdep.cpu.* / kern.cpufrequency_*)` |
| GPU | GPU 名称、显存（推荐工作集）、线程组上限 | `MTLCreateSystemDefaultDevice`（Metal） |
| 屏幕刷新率 | 最大帧率（ProMotion） | `UIScreen.maximumFramesPerSecond` |
| 屏幕可用模式 | 支持的分辨率模式列表 | `UIScreen.availableModes` |
| 安全区域 | 顶部/底部 insets（刘海/灵动岛） | `UIWindowScene` + `safeAreaInsets` |
| 生物识别 | Face ID / Touch ID / Optic ID + 是否设密码 | `LAContext`（LocalAuthentication） |
| NFC | NFC 读取能力 | `NFCNDEFReaderSession.readingAvailable` |
| 多任务 | iPad 多任务支持 | `UIDevice.isMultitaskingSupported` |
| 通知权限 | 通知授权状态 | `UNUserNotificationCenter` |
| 定位精度 | 精确/粗略位置授权 | `CLLocationManager.accuracyAuthorization` |
| 时区扩展 | 本地化名称、下次夏令时切换 | `TimeZone.localizedName` / `nextDaylightSavingTimeTransition` |
| 格式化设置 | 小数/千分位分隔符 | `Locale.decimalSeparator` / `groupingSeparator` |
| 存储细节 | 可清空容量（opportunistic） | `volumeAvailableCapacityForOpportunisticUsageKey` |
| 录音权限 | 麦克风录音授权状态 | `AVAudioSession.recordPermission` |
| 启动参数 | 进程启动参数 | `ProcessInfo.arguments` |
| 进程内存 | 常驻/虚拟/可用内存 | `task_info`、`os_proc_available_memory()` |
| 系统构建 | 产品版本、构建号 | `sysctl(kern.osproductversion / osproductbuild)` |
| 模拟器识别 | 是否模拟器 + 模拟器型号 | `#if targetEnvironment(simulator)`、`SIMULATOR_DEVICE_NAME` |
| 本地 IP | 本机 IPv4（WiFi/蜂窝） | `getifaddrs` + `getnameinfo` |
| 网络接口 | en0/pdp_ip0/lo0 全部 IPv4 地址 | `getifaddrs` |
| 公网 IP | 本机公网出口 IP | 多源轮询（`api.ipify.org` / `ipinfo.io` / `ip.3322.net` / `myip.ipip.net`）+ IP 正则提取 |
| UI 外观 | 深色模式、色彩范围、尺寸类、字体大小、对比度 | `UITraitCollection` |
| 音频环境 | 输出设备、音量、采样率 | `AVAudioSession` |
| 系统设置 | 历法、每周起始日、公制单位、温度单位、已装键盘 | `Calendar`、`UserDefaults` |
| 应用能力 | 后台刷新、多场景、禁止休眠 | `UIApplication` |
| 运动传感器 | 加速度、陀螺仪、磁力计、设备运动实时数据 + 可用性 | `CMMotionManager` |
| 气压计 | 相对气压、海拔 | `CMAltimeter` |
| 运动状态 | 步行/跑步/驾车识别 | `CMMotionActivityManager` |
| 定位与航向 | 经纬度、海拔、航向角、速度、精度 | `CLLocationManager` |
| 摄像头 | 前后摄像头数量、闪光灯、权限状态 | `AVCaptureDevice` |
| 音频输入 | 麦克风数量、输入声道、权限状态 | `AVAudioSession` |
| 广告标识 | IDFA + 追踪授权状态 | `ASIdentifierManager` + `ATTrackingManager` |
| 推送令牌 | APNs DeviceToken + 注册状态 | `UIApplication.registerForRemoteNotifications` + AppDelegate |
| 越狱检测 | 常见越狱文件标记探测 | `FileManager.fileExists` |
| 时钟偏差 | 系统时间与开机时间推算的偏差（近似 NTP 偏移） | `kern.boottime` + `systemUptime` 对比 |
| DNS 服务器 | 当前 DNS 服务器地址 | libresolv `res_9_getservers`（经 BridgingHeader） |

### 未来可扩展（未实现）

表内此前所列项已全部实现。以下项目**公开 API 无法实现**，需私有 API（如 `MobileGestalt`），出于上架合规考虑本工程跳过：

| 类别 | 内容 | 说明 |
| --- | --- | --- |
| 屏幕厂商/型号 | 屏幕面板厂商、部件型号 | 公开 API（`UIScreen`）只有尺寸/色彩/刷新率/亮度，无部件信息 |
| 电池厂商/循环次数/健康度 | 电池厂商、循环次数、健康度 | `UIDevice` 只有电量与充电状态 |
| 外来部件检测 | 屏幕/电池/摄像头是否原装（第三方更换件） | 即系统"部件与服务历史"，仅苹果私有框架 `MobileGestalt`（`MGCopyAnswer`）可读，需 `BatteryCycleCount`/`PartHistory` 等私有键，且 App Store 扫描私有符号会被拒 |

> 各 API 的权限要求：运动传感器/气压计无需权限（仅 App 运行时有效），运动状态需 Motion & Fitness 权限，定位需定位权限，IDFA 需 AppTrackingTransparency 弹窗，推送需推送 capability。
>
> **DNS 实现要点**：iOS 上 `libresolv` 无 Swift module，需新建 `BridgingHeader.h`（`#include <resolv.h>`）+ 设置 `SWIFT_OBJC_BRIDGING_HEADER` + `OTHER_LDFLAGS = -lresolv`。且 Apple 平台 resolv.h 把符号 `#define` 重命名为 `res_9_` 前缀，Swift 里必须用 `res_9_ninit` / `res_9_getservers` / `res_9_nclose`，`res_state` 是指针 typedef 需 `allocate` 分配。

---

## 7. 动态信息监听机制

### 7.1 startMonitoring

```swift
private func startMonitoring() {
    // 1. 开启 UIDevice 监测
    device.beginGeneratingDeviceOrientationNotifications()
    device.isBatteryMonitoringEnabled = true
    device.isProximityMonitoringEnabled = true

    // 2. 方向 / 电量 / 接近 → NotificationCenter + Combine
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

    // 3. 亮度变化通知
    NotificationCenter.default
        .publisher(for: UIScreen.brightnessDidChangeNotification)
        .sink { [weak self] _ in
            self?.currentBrightness = UIScreen.main.brightness
        }
        .store(in: &cancellables)

    // 4. 散热状态 / 低电量模式：无通知，只能轮询（主 RunLoop 每 2s）
    pollingCancellable = Timer.publish(every: 2, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in self?.updateDynamicInfo() }

    // 5. 网络监听：NWPathMonitor，后台队列回调 → 切回主线程更新
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
        DispatchQueue.main.async {
            self?.updateNetworkInfo(path)
        }
    }
    monitor.start(queue: DispatchQueue.global(qos: .background))
    self.monitor = monitor

    // 6. 立即更新一次
    updateDynamicInfo()
}
```

### 7.2 updateDynamicInfo / stopMonitoring

```swift
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
}
```

---

## 8. 辅助工具方法（static）

```swift
// 通用 sysctl 字符串读取
static func sysctlString(_ name: String) -> String {
    var size = 0
    sysctlbyname(name, nil, &size, nil, 0)
    guard size > 0 else { return "" }
    var buffer = [CChar](repeating: 0, count: size)
    sysctlbyname(name, &buffer, &size, nil, 0)
    return String(cString: buffer)
}

// kern.boottime 开机时刻
static func bootTime() -> Date? {
    var tv = timeval()
    var size = MemoryLayout<timeval>.size
    guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
    return Date(timeIntervalSince1970: Double(tv.tv_sec))
}

// 字节数 → 人类可读
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

// 枚举 → 中文（private 实例方法）
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

private func orientationString(_ o: UIDeviceOrientation) -> String {
    switch o {
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

private func batteryStateString(_ s: UIDevice.BatteryState) -> String {
    switch s {
    case .unknown: return "未知"
    case .unplugged: return "未充电"
    case .charging: return "充电中"
    case .full: return "已充满"
    @unknown default: return "未知"
    }
}

private func thermalString(_ t: ProcessInfo.ThermalState) -> String {
    switch t {
    case .nominal: return "正常"
    case .fair: return "略热"
    case .serious: return "过热"
    case .critical: return "严重过热"
    @unknown default: return "未知"
    }
}

private func appStateString(_ s: UIApplication.State) -> String {
    switch s {
    case .active: return "前台活跃"
    case .inactive: return "前台非活跃"
    case .background: return "后台"
    @unknown default: return "未知"
    }
}

private func radioTechString(_ tech: String?) -> String {
    guard let tech else { return "未知" }
    switch tech {
    case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
        return "2G"
    case CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
         CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyCDMAEVDORev0,
         CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB:
        return "3G"
    case CTRadioAccessTechnologyLTE: return "4G LTE"
    case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA: return "5G"
    default: return tech
    }
}
```

---

## 9. Info.plist 与 scheme 配置

工程使用 `GENERATE_INFOPLIST_FILE = YES`，`LSApplicationQueriesSchemes` 无法通过 `INFOPLIST_KEY_*` 生成，需要物理 `Info.plist` 文件，构建时 Xcode 会自动与生成键合并。

### 9.1 新建 `AC/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>weixin</string>
        <string>mqq</string>
        <string>alipay</string>
        <string>taobao</string>
        <string>openapp.jdmobile</string>
        <string>snssdk1128</string>
        <string>sinaweibo</string>
        <string>bilibili</string>
        <string>imeituan</string>
        <string>iosamap</string>
    </array>
</dict>
</plist>
```

> scheme 清单必须与 `DeviceManager.schemeCatalog` 一致，否则 `canOpenURL` 恒为 false。

### 9.2 pbxproj 配置

打开 `AC.xcodeproj/project.pbxproj`，在 target `AC` 的 **Debug 和 Release 两个** `XCBuildConfiguration`（`012B5C89...` 和 `012B5C8A...`）的 `buildSettings` 里各加一行：

```
INFOPLIST_FILE = "AC/Info.plist";
```

保留 `GENERATE_INFOPLIST_FILE = YES`，Xcode 会合并两者（`Info.plist` 中的键优先）。

> 可能的问题：文件系统同步组会把 `Info.plist` 也当资源复制，导致 "Multiple commands produce" 报错。若出现，需要在同步组的 exceptions 中排除 `Info.plist`（在 Xcode 的 File Inspector → Membership 里取消勾选 target，或编辑 pbxproj 的 `PBXFileSystemSynchronizedRootGroup`）。

---

## 10. SwiftUI 界面接线

### 10.1 ACApp.swift

```swift
import SwiftUI

@main
struct ACApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DeviceInfoView().tabItem { Label("设备", systemImage: "iphone") }
                SystemInfoView().tabItem { Label("系统", systemImage: "gearshape.2") }
                ScreenHardwareView().tabItem { Label("屏幕硬件", systemImage: "display") }
                BundleInfoView().tabItem { Label("当前App", systemImage: "app.badge") }
                InstalledAppsView().tabItem { Label("已安装App", systemImage: "square.grid.2x2") }
            }
        }
    }
}
```

### 10.2 各 View 的统一模式

每个 View 只做两件事：读 `DeviceManager.shared`、按 Section 展示。支持下拉刷新。

```swift
struct SystemInfoView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("进程与系统") {
                InfoRow(label: "开机时间", value: manager.systemInfo.uptimeText)
                InfoRow(label: "系统版本", value: manager.systemInfo.osVersionString)
                InfoRow(label: "物理内存", value: manager.systemInfo.physicalMemoryText)
                InfoRow(label: "CPU 核数", value: "\(manager.systemInfo.processorCount)（活跃 \(manager.systemInfo.activeProcessorCount)）")
                InfoRow(label: "处理器", value: manager.systemInfo.cpuBrandString)
                InfoRow(label: "散热状态", value: manager.thermalState)
                InfoRow(label: "低电量模式", value: manager.lowPowerMode ? "开启" : "关闭")
            }
            Section("本地化与时区") {
                InfoRow(label: "首选语言", value: manager.systemInfo.languageText)
                InfoRow(label: "地区", value: manager.systemInfo.localeIdentifier)
                InfoRow(label: "时区", value: manager.systemInfo.timeZoneIdentifier)
                InfoRow(label: "GMT 偏移", value: "\(manager.systemInfo.secondsFromGMT / 3600) 小时")
            }
        }
        .navigationTitle("系统信息")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}
```

### 10.3 已安装 App 页（含唤醒功能）

```swift
struct InstalledAppsView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("说明") {
                Text("仅能探测 Info.plist 中声明的 scheme（上限 50 个），点击可唤起对应 App。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section("常用 App") {
                ForEach(manager.installedApps) { app in
                    HStack {
                        Image(systemName: app.iconName)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.scheme)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(app.isInstalled ? "已安装" : "未安装")
                            .foregroundColor(app.isInstalled ? .green : .gray)
                        Button("打开") {
                            manager.openApp(app)
                        }
                        .disabled(!app.isInstalled)
                    }
                }
            }
        }
        .navigationTitle("已安装 App")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshInstalledApps() }
    }
}
```

---

## 11. 实施步骤清单

按此顺序实现，每一步编译通过再进下一步：

- [ ] **Step 1**：新建 `AC/Models/DeviceModels.swift`，写完 9 个 struct（含计算属性）
- [ ] **Step 2**：新建 `AC/DeviceManager.swift`，先写单例骨架 + 属性 + `refreshAll`（各 refresh 留空）
- [ ] **Step 3**：逐个实现 `refreshDeviceInfo` → `refreshSystemInfo` → `refreshScreenInfo` → `refreshMemoryInfo` → `refreshStorageInfo` → `refreshCarrierInfo` → `refreshBundleInfo` → `refreshInstalledApps`
- [ ] **Step 4**：实现 static 辅助工具（`sysctlString` / `bootTime` / `byteString`）与各枚举转换方法
- [ ] **Step 5**：实现 `startMonitoring` / `stopMonitoring` / `updateDynamicInfo`（通知 + 轮询 + NWPathMonitor）
- [ ] **Step 6**：实现 `openApp`，写 `schemeCatalog`
- [ ] **Step 7**：新建 `AC/Info.plist` + 修改 pbxproj 加 `INFOPLIST_FILE`
- [ ] **Step 8**：新建 5 个 View（可复用现有 `InfoRow`），改 `ACApp.swift` 为 TabView
- [ ] **Step 9**：验证——模拟器运行，逐个 Tab 检查数据；真机再测一遍
- [ ] **Step 10**：确认 DeviceManager 正常工作后，删除旧 `UIDevice.swift` 中的 `DeviceInfoViewModel`（保留 `InfoRow` 或移到公共文件）

---

## 12. 注意事项与常见坑

1. **`canOpenURL` 声明限制**：未在 `LSApplicationQueriesSchemes` 声明的 scheme 恒返回 `false`，且上限 50 个。
2. **探测结果非实时**：`canOpenURL` 结果只在 App 运行期间有效，运行中安装/卸载 App 需重启 App 才更新。
3. **MainActor 默认隔离**：工程设置了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。`NWPathMonitor` 回调在后台队列，必须用 `DispatchQueue.main.async` 切回主线程再更新 `@Published`（轮询用 `Timer.publish(on: .main)` 避免隔离问题）。
4. **部分 API 在 iOS 上不存在**：`ProcessInfo.processorName`、`UIScreen.maximumBrightness`、`UIScreenMode.pixelWidth` 等编译会报 "no member"，需改用可用 API（如 `currentMode.size`）或移除。
5. **内存数据是估算**：`used = total - free`，iOS Memory Status 机制下不精确，仅供学习。
6. **模拟器数据差异**：电池恒"充电中/未知"、运营商为空、接近传感器无效果、WiFi SSID 拿不到（返回 nil）。
7. **`Info.plist` 合并**：若报 "Multiple commands produce Info.plist"，从 target membership 中取消勾选 Info.plist。
8. **`private(set)` 只读**：View 无法篡改数据，只能读；刷新只能通过 `DeviceManager.shared.refreshAll()`。
9. **`backgroundTimeRemaining` 转 Int 会崩溃**：前台运行时 `UIApplication.shared.backgroundTimeRemaining` 返回 `Double.greatestFiniteMagnitude`。注意它的 `isFinite` 为 `true`（只是极大），`guard isFinite` 拦不住，直接 `Int(remaining)` 会触发 `EXC_BREAKPOINT` 闪退。必须先与 `Double(Int.max)` 比较：
   ```swift
   guard remaining < Double(Int.max) else { return "前台运行，无限制" }
   return "\(Int(remaining)) 秒"
   ```
10. **WiFi SSID 拿不到**：需要 wifi-info entitlement + 定位授权 + 真机，缺任一个回调即为 `nil`。**免费个人 team 无法注册该 capability**（真机签名报 "doesn't include the ... entitlement"），**付费账号也需要 Xcode 自动重新生成 profile 才生效**。此外 App 必须主动请求定位授权（`CLLocationManager.requestWhenInUseAuthorization()`），未授权时返回 nil。
11. **`import Network` 与 `import NetworkExtension` 冲突**：两者都有 `NWPath`，类型查找会报 "ambiguous"，用 `Network.NWPath` 显式限定即可。
12. **Bundle ID 必须唯一**：免费个人 team 下，通用 Bundle ID（如 `com.test.AC`）无法注册到你的开发者账号，真机报 "The app identifier ... cannot be registered"。需改成唯一字符串（本工程为 `com.b.ACDeviceInfo`，可在 Signing & Capabilities 里改）。
13. **主机名因运行环境而异**：`ProcessInfo.processInfo.hostName` 返回 BSD 网络主机名——模拟器上恒为 `localhost`，真机上才是设备名（Bonjour 名，如 `孙梦龙的iPhone.local`）。想显示用户设置的设备名请用 `UIDevice.current.name`。
14. **新增权限说明**：运动状态需在 Info.plist 加 `NSMotionUsageDescription`（`CMMotionActivityManager` 未声明会在启动时崩溃）；IDFA 需 `NSUserTrackingUsageDescription` + `ATTrackingManager` 弹窗；推送需注册 `registerForRemoteNotifications`，模拟器上必然回调 `didFailToRegister`（无 aps-environment），属预期。
15. **模拟器环境差异**：`CMMotionManager` 各传感器在模拟器上不可用（显示"无可用传感器"）、`registerForRemoteNotifications` 失败、越狱检测因 `/bin/bash` 等文件在模拟器运行时存在而**误报"疑似越狱"**，均属预期，需真机验证。
16. **`CLLocationManagerDelegate` 需继承 NSObject**：让 `DeviceManager: NSObject, ObservableObject, CLLocationManagerDelegate`，`init` 改为 `override init()`。
17. **`import resolv` 不可用，需 BridgingHeader**：iOS 上 libresolv 没有 Swift module，直接 `import resolv` 报错。变通方案：新建 `BridgingHeader.h`（`#include <resolv.h>`）+ `SWIFT_OBJC_BRIDGING_HEADER` 构建设置 + `OTHER_LDFLAGS` 加 `-lresolv`。注意 Apple 平台 resolv.h 把符号重命名为 `res_9_` 前缀，Swift 侧要用 `res_9_ninit`/`res_9_getservers`/`res_9_nclose`；`res_state` 是指针 typedef，需 `res_9_state.allocate(capacity: 1)` + `memset` 清零后传入。
18. **公网 IP 服务可能超时/被墙**：`api.ipify.org`、`ifconfig.me` 等在部分网络环境（尤其国内）会超时。改用多源轮询（`ipinfo.io/ip`、`ip.3322.net`、`myip.ipip.net` 等），并用正则从响应文本提取 IPv4（`myip.ipip.net` 返回带描述文本）。

---

## 13. API 信息源汇总表

| 信息源 | 所属框架 | 能获取什么 | 权限需求 |
| --- | --- | --- | --- |
| `UIDevice` | UIKit | 设备名称、型号、系统版本、电池、方向、接近传感器 | 无 |
| `sysctl` | Darwin | 硬件型号、CPU 品牌、开机时间、内核信息 | 无 |
| `ProcessInfo` | Foundation | 内存、CPU 核数、系统版本、散热、低电量 | 无 |
| `UIScreen` | UIKit | 分辨率、Scale、亮度 | 无 |
| `host_statistics64` | Mach | 实时内存统计 | 无 |
| `FileManager` | Foundation | 磁盘容量、沙盒目录 | 无 |
| `NWPathMonitor` | Network | 网络连接类型、是否计费/受限 | 无 |
| `NEHotspotNetwork` | NetworkExtension | WiFi SSID / BSSID | 需 wifi-info entitlement + 定位权限 |
| `CTTelephonyNetworkInfo` | CoreTelephony | 运营商名称、制式 | 无 |
| `NSLocale` / `TimeZone` | Foundation | 语言、地区、时区、夏令时 | 无 |
| `Bundle` / `UIApplication` | Foundation / UIKit | 应用自身信息、运行状态、沙盒路径 | 无 |
| `canOpenURL` / `open` | UIKit | 探测已安装 App 并唤起 | 需声明 scheme |
| `host_cpu_load_info` | Mach | 总 CPU 使用率 | 无 |
| `task_info` | Mach | 本进程常驻/虚拟内存 | 无 |
| `os_proc_available_memory` | Darwin | 本进程可用内存 | 无 |
| `getifaddrs` | Darwin | 本机 IPv4、接口列表 | 无 |
| `MTLCreateSystemDefaultDevice` | Metal | GPU 名称、显存、线程组上限 | 无 |
| `CMMotionManager` | CoreMotion | 加速度、陀螺仪、磁力计、设备运动 | 无（仅运行时有效） |
| `CMAltimeter` | CoreMotion | 相对气压、海拔 | 无（仅运行时有效） |
| `CMMotionActivityManager` | CoreMotion | 步行/跑步/驾车状态 | 需 Motion & Fitness 权限 |
| `CLLocationManager` | CoreLocation | 经纬度、海拔、航向、速度 | 需定位权限 |
| `AVCaptureDevice` | AVFoundation | 摄像头数量、闪光灯、权限状态 | 无（权限状态查询） |
| `AVAudioSession` | AVFoundation | 输出/输入设备、音量、采样率、声道 | 无 |
| `ASIdentifierManager` | AdSupport | IDFA | 需 AppTrackingTransparency |
| `ATTrackingManager` | AppTrackingTransparency | 追踪授权状态 | 需弹窗 |
| `registerForRemoteNotifications` | UIKit | APNs DeviceToken | 需推送 capability |
| `api.ipify.org` 等 | 网络 | 公网出口 IP（多源轮询） | 需网络 |
| libresolv `res_9_getservers` | libresolv | DNS 服务器地址 | 无（需 BridgingHeader） |
| `LAContext` | LocalAuthentication | Face ID/Touch ID/Optic ID、是否设密码 | 无 |
| `NFCNDEFReaderSession` | CoreNFC | NFC 读取能力 | 无 |
| `UNUserNotificationCenter` | UserNotifications | 通知授权状态 | 无 |
| `UIScreen.availableModes` | UIKit | 支持的分辨率模式列表 | 无 |

### 已安装 App 探测的局限性

1. **无法枚举完整列表**：只能探测主动声明过的 scheme，且上限 50 个。
2. **覆盖不全面**：`canOpenURL` 只对声明过的 scheme 返回有效结果。
3. **非运行期缓存**：探测结果仅在 App 运行期间有效。
4. **scheme 不稳定**：属各 App 自定义，可能随版本变更或隐藏。
5. **补充方案**：Universal Link（`apple-app-site-association`）也可尝试唤起，但需要关联域名配置，未在本次实现范围。

---

## 14. App Store 审核清单

> 本文档用于排查上架风险。整体判断：本类"设备信息展示" App 是可过审的品类，但本工程存在若干会被 Review 追问/驳回的点，逐一处理后可显著提高通过率。

### 14.1 高危风险点（建议上架前处理）

| # | 风险点 | 涉及 Guideline | 风险 | 处理建议 |
| --- | --- | --- | --- | --- |
| 1 | **IDFA + ATT 弹窗**：请求了广告追踪权限，但 App 不投放广告、不用 IDFA 做追踪 | 5.1.2 (Tracking) | 高 | **删除 IDFA 逻辑**（`requestIDFA`、`ASIdentifierManager`、`ATTrackingManager`、`NSUserTrackingUsageDescription`） |
| 2 | **精准定位**：采集经纬度/海拔/航向/速度 | 5.1.1 (Data Collection) | 中高 | App Privacy 如实勾选"精确位置"；审核备注说明用途为"展示设备定位能力"；提供"不使用定位"的降级路径 |
| 3 | **WiFi SSID/BSSID** | 5.1.1、隐私标签 | 中 | App Privacy 声明 WiFi 信息；审核备注说明需 wifi-info entitlement 的用途 |
| 4 | **推送令牌**：注册远程推送但无实际推送服务 | 4.2、5.1.1 | 中 | 删除 `registerForRemoteNotifications`，或接入真实推送并说明用途 |
| 5 | **运动与健身权限**（`CMMotionActivityManager`） | 5.1.1、隐私标签 | 中低 | App Privacy 声明"运动与健身"数据；若仅展示可考虑改为"未收集"并移除采集 |
| 6 | **越狱检测** | 5.1 | 低 | 本身不违规（银行/安全类常见），保留即可 |

### 14.2 必须做的配置

- [ ] **App Privacy（隐私营养标签）**：数据种类多，必须逐一准确填写，错填/漏填会被拒或下架。本工程涉及的数据类型：
  - 位置（精确/粗略）—— `CLLocationManager`
  - WiFi 信息（SSID/BSSID）—— `NEHotspotNetwork`
  - 运动与健身 —— `CMMotionActivityManager` / `CMAltimeter`
  - 设备/系统信息（标识符、CPU、内存等）—— 各系统 API
  - 网络（连接类型、IP、DNS、公网 IP）—— `NWPathMonitor` / `getifaddrs` / 第三方 IP 服务
  - 运营商 —— `CTTelephonyNetworkInfo`
  - 标识符（DeviceToken / Vendor ID）—— 如保留推送则需声明
  - 生物识别/密码状态（Face ID、是否设密码）—— `LAContext` 查询结果，属敏感数据需如实声明
  - 通知授权状态 —— `UNUserNotificationCenter`
- [ ] **App Tracking Transparency**：若保留 IDFA 必须在 `NSUserTrackingUsageDescription` 写清用途，且实际用于追踪；**建议删除以规避风险**
- [ ] **权限描述文案**：`Info.plist` 中定位/运动/追踪（若保留）的 `NSXxxUsageDescription` 必须与真实用途一致
- [ ] **审核备注（App Review Information）**：逐条说明每个权限的用途（定位、WiFi、运动），减少追问轮次
- [ ] **崩溃与性能（Guideline 2.1）**：真机全流程回归——CoreMotion、定位、ATT、前后台切换、多权限组合场景
- [ ] **付费开发者账号**：$99/年，个人免费 team 无法上架
- [ ] **最低功能（Guideline 4.2）**：本工程数据量大、非"低质填充"，此项通常无忧

### 14.3 上架成本与市场概况

| 项目 | 说明 |
| --- | --- |
| 开发者账号 | $99/年（个人）或 $299/年（企业） |
| 竞品 | AIDA64（iOS 版）、DevCheck Device & System Info、Lirum Device Info、System Status Lite/Pro、Phone Info、Network Analyzer、Fing、Battery HD+ |
| 收费模式 | 主流为**免费+广告** 或 **一次性低价买断**（约 $1.99–$4.99），设备信息类几乎没有纯订阅模式，付费天花板低 |
| 建议定位 | 免费版 + 广告 / 精简版 + 买断 Pro（去广告、更多数据），需结合隐私标签规划 |

---

## 15. 免责声明

本项目仅供学习参考，不涉及任何私有 API，符合 App Store 审核规范。
