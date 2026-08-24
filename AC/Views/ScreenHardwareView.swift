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
            Section("屏幕") {
                InfoRow(label: "逻辑尺寸 (pt)", value: manager.screenInfo.bounds)
                InfoRow(label: "物理尺寸 (px)", value: manager.screenInfo.nativeBounds)
                InfoRow(label: "Scale", value: manager.screenInfo.scaleText)
                InfoRow(label: "Native Scale", value: manager.screenInfo.nativeScaleText)
                InfoRow(label: "像素尺寸", value: manager.screenInfo.pixelSize)
                InfoRow(label: "可用模式", value: manager.screenInfo.availableModes.isEmpty ? "未知" : manager.screenInfo.availableModes)
                InfoRow(label: "当前亮度", value: "\(Int(manager.currentBrightness * 100))%")
            }

            Section("内存") {
                InfoRow(label: "物理内存", value: manager.memoryInfo.totalText)
                InfoRow(label: "已用内存", value: manager.memoryInfo.usedText)
                InfoRow(label: "空闲内存", value: manager.memoryInfo.freeText)
                InfoRow(label: "活跃", value: manager.memoryInfo.activeText)
                InfoRow(label: "非活跃", value: manager.memoryInfo.inactiveText)
                InfoRow(label: "固定 (wired)", value: manager.memoryInfo.wiredText)
            }

            Section("存储") {
                InfoRow(label: "总容量", value: manager.storageInfo.totalText)
                InfoRow(label: "可用容量", value: manager.storageInfo.availableText)
                InfoRow(label: "可清空容量", value: manager.storageInfo.purgeableText)
            }

            Section("网络") {
                InfoRow(label: "连接类型", value: manager.currentConnectionType)
                InfoRow(label: "本地 IP", value: manager.networkInfo.localIP)
                InfoRow(label: "公网 IP", value: manager.externalIPAddress)
                InfoRow(label: "DNS 服务器", value: manager.dnsServers)
                InfoRow(label: "计费网络", value: manager.networkInfo.isExpensive ? "是" : "否")
                InfoRow(label: "受限网络", value: manager.networkInfo.isConstrained ? "是" : "否")
            }

            Section("网络接口") {
                Text(manager.networkInterfaces)
                    .font(.footnote)
                    .monospaced()
                    .foregroundColor(.secondary)
            }

            Section("WiFi") {
                InfoRow(label: "SSID", value: manager.networkInfo.ssid)
                InfoRow(label: "BSSID", value: manager.networkInfo.bssid.isEmpty ? "未知" : manager.networkInfo.bssid)
            }

            Section("界面环境") {
                InfoRow(label: "深色模式", value: manager.environmentInfo.isDarkMode ? "开启" : "关闭")
                InfoRow(label: "色彩范围", value: manager.environmentInfo.displayGamut)
                InfoRow(label: "水平尺寸类", value: manager.environmentInfo.horizontalSizeClass)
                InfoRow(label: "垂直尺寸类", value: manager.environmentInfo.verticalSizeClass)
                InfoRow(label: "字体大小", value: manager.environmentInfo.contentSizeCategory)
                InfoRow(label: "对比度", value: manager.environmentInfo.accessibilityContrast)
            }

            Section("音频环境") {
                InfoRow(label: "输出设备", value: manager.environmentInfo.audioRouteText)
                InfoRow(label: "输出音量", value: manager.environmentInfo.outputVolumeText)
                InfoRow(label: "采样率", value: manager.environmentInfo.sampleRateText)
            }

            Section("相机与麦克风") {
                InfoRow(label: "相机数量", value: "\(manager.environmentInfo.cameraCount)（前 \(manager.environmentInfo.frontCameraCount) / 后 \(manager.environmentInfo.backCameraCount)）")
                InfoRow(label: "闪光灯", value: manager.environmentInfo.hasFlash ? "支持" : "不支持")
                InfoRow(label: "相机权限", value: manager.environmentInfo.cameraAuthStatus)
                InfoRow(label: "麦克风数量", value: "\(manager.environmentInfo.microphoneCount)")
                InfoRow(label: "输入声道", value: "\(manager.environmentInfo.inputChannelCount)")
                InfoRow(label: "麦克风权限", value: manager.environmentInfo.microphoneAuthStatus)
                InfoRow(label: "录音权限", value: manager.environmentInfo.audioRecordPermission)
            }

            Section("日历与系统设置") {
                InfoRow(label: "历法", value: manager.environmentInfo.calendarIdentifier)
                InfoRow(label: "每周起始日", value: weekdayText(manager.environmentInfo.firstWeekday))
                InfoRow(label: "公制单位", value: manager.environmentInfo.usesMetricSystem ? "是" : "否")
                InfoRow(label: "温度单位", value: manager.environmentInfo.temperatureUnit)
                InfoRow(label: "时区缩写", value: manager.environmentInfo.timeZoneAbbreviation)
                InfoRow(label: "已装键盘", value: manager.environmentInfo.keyboards)
            }

            Section("运营商") {
                InfoRow(label: "运营商", value: manager.carrierInfo.carrierName)
                InfoRow(label: "MCC", value: manager.carrierInfo.mobileCountryCode)
                InfoRow(label: "MNC", value: manager.carrierInfo.mobileNetworkCode)
                InfoRow(label: "国家码", value: manager.carrierInfo.isoCountryCode)
                InfoRow(label: "网络制式", value: manager.carrierInfo.radioAccessTechnology)
            }
        }
        .navigationTitle("屏幕与硬件")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private func weekdayText(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "未知" }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[weekday - 1]
    }
}

#Preview {
    ScreenHardwareView()
}
