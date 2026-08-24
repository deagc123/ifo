# ifo

A privacy-first iOS device inspector. Peek into every corner of your iPhone / iPad — hardware, system, sensors, network, and installed apps — presented in a clean, "Settings"-style SwiftUI interface.

## Features

- **Device & System** — model, CPU cores/frequency, memory, storage, uptime, locale, timezone, thermal state
- **Screen & Hardware** — resolution, brightness, ProMotion refresh rate, GPU (Metal), Face ID / Touch ID, NFC, safe-area
- **Real-time Sensors** — accelerometer, gyroscope, magnetometer, barometer, motion activity, GPS
- **Network & Carrier** — connection type, WiFi SSID/BSSID, local & public IP, DNS servers, cellular info
- **Installed Apps** — detect and launch apps via URL schemes
- **Environment** — dark mode, audio, cameras, keyboards, jailbreak check, live battery / orientation / proximity

All data stays on-device; public APIs only, no private frameworks. See `审核清单.md` for App Store compliance notes.

## Tech

SwiftUI + Combine · UIKit · CoreTelephony · CoreLocation · CoreMotion · Network / NWPathMonitor · Metal · LocalAuthentication · CoreNFC

---

# ifo

一款注重隐私的 iOS 设备信息检测工具。以「系统设置」风格的 SwiftUI 界面，查看 iPhone / iPad 的硬件、系统、传感器、网络与已装应用信息。

## 功能

- **设备与系统** — 型号、CPU 核心/频率、内存、存储、开机时长、语言地区、时区、散热状态
- **屏幕与硬件** — 分辨率、亮度、ProMotion 刷新率、GPU（Metal）、Face ID / Touch ID、NFC、安全区域
- **实时传感器** — 加速度计、陀螺仪、磁力计、气压计、运动状态、GPS
- **网络与运营商** — 连接类型、WiFi SSID/BSSID、本地/公网 IP、DNS 服务器、蜂窝信息
- **已装应用** — 通过 URL scheme 探测并唤起常用 App
- **环境信息** — 深色模式、音频、摄像头、键盘、越狱检测，以及电量/方向/接近传感器的实时状态

所有数据仅在本机展示，全部使用公开 API，无私有框架。上架合规说明见 `审核清单.md`。

## 技术栈

SwiftUI + Combine · UIKit · CoreTelephony · CoreLocation · CoreMotion · Network / NWPathMonitor · Metal · LocalAuthentication · CoreNFC
