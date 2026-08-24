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
            Section("进程与系统") {
                InfoRow(label: "开机运行时间", value: manager.systemInfo.uptimeText)
                InfoRow(label: "系统版本", value: manager.systemInfo.osVersionString)
                InfoRow(label: "产品版本", value: manager.systemInfo.osProductVersion.isEmpty ? "未知" : manager.systemInfo.osProductVersion)
                InfoRow(label: "构建号", value: manager.systemInfo.osProductBuild.isEmpty ? "未知" : manager.systemInfo.osProductBuild)
                InfoRow(label: "物理内存", value: manager.systemInfo.physicalMemoryText)
                InfoRow(label: "CPU 使用率", value: manager.systemInfo.cpuUsageText)
                InfoRow(label: "CPU 频率", value: manager.systemInfo.cpuFrequencyText)
                InfoRow(label: "CPU 核数", value: "\(manager.systemInfo.processorCount)（活跃 \(manager.systemInfo.activeProcessorCount)）")
                InfoRow(label: "核心/线程", value: manager.systemInfo.coreThreadText)
                InfoRow(label: "CPU 品牌", value: manager.systemInfo.cpuBrandString)
                InfoRow(label: "硬件型号", value: manager.systemInfo.hwModel.isEmpty ? "未知" : manager.systemInfo.hwModel)
                InfoRow(label: "内核版本", value: manager.systemInfo.kernOSVersion)
                InfoRow(label: "开机时刻", value: manager.systemInfo.bootTimeText)
                InfoRow(label: "主机名", value: manager.systemInfo.hostName)
                InfoRow(label: "运行环境", value: manager.systemInfo.isSimulator ? "模拟器（\(manager.systemInfo.simulatorDeviceName)）" : "真机")
                InfoRow(label: "散热状态", value: manager.thermalState)
                InfoRow(label: "低电量模式", value: manager.lowPowerMode ? "开启" : "关闭")
            }

            Section("本进程内存") {
                InfoRow(label: "常驻内存 (resident)", value: manager.systemInfo.processResidentText)
                InfoRow(label: "虚拟内存", value: manager.systemInfo.processVirtualText)
                InfoRow(label: "可用内存", value: manager.systemInfo.processAvailableText)
            }

            Section("硬件详情") {
                InfoRow(label: "设备机型", value: manager.hardwareInfo.deviceName)
                InfoRow(label: "页面大小", value: "\(manager.hardwareInfo.pageSize) 字节")
                InfoRow(label: "物理/逻辑核", value: "\(manager.hardwareInfo.physicalCPU) / \(manager.hardwareInfo.logicalCPU)")
                InfoRow(label: "物理封装", value: "\(manager.hardwareInfo.packages)")
                InfoRow(label: "CPU 细分", value: manager.hardwareInfo.detailText)
                InfoRow(label: "CPU 频率范围", value: manager.hardwareInfo.cpuFreqText)
                InfoRow(label: "GPU 名称", value: manager.hardwareInfo.gpuName)
                InfoRow(label: "GPU 显存", value: manager.hardwareInfo.gpuWorkingSetText)
                InfoRow(label: "GPU 线程组上限", value: "\(manager.hardwareInfo.gpuMaxThreadsPerGroup)")
                InfoRow(label: "最大刷新率", value: manager.hardwareInfo.refreshRateText)
                InfoRow(label: "安全区域", value: manager.hardwareInfo.safeAreaText)
                InfoRow(label: "多任务支持", value: manager.hardwareInfo.isMultitaskingSupported ? "支持" : "不支持")
                InfoRow(label: "生物识别", value: manager.hardwareInfo.biometricType)
                InfoRow(label: "已设密码", value: manager.hardwareInfo.hasPasscode ? "是" : "否")
                InfoRow(label: "NFC 读取", value: manager.hardwareInfo.nfcSupported ? "支持" : "不支持")
            }

            Section("本地化与时区") {
                InfoRow(label: "首选语言", value: manager.systemInfo.languageText)
                InfoRow(label: "Locale", value: manager.systemInfo.localeIdentifier)
                InfoRow(label: "国家/地区", value: manager.systemInfo.regionCode)
                InfoRow(label: "货币", value: manager.systemInfo.currencyCode)
                InfoRow(label: "时区", value: manager.systemInfo.timeZoneIdentifier)
                InfoRow(label: "时区名称", value: manager.environmentInfo.timeZoneLocalizedName)
                InfoRow(label: "GMT 偏移", value: "\(manager.systemInfo.secondsFromGMT / 3600) 小时")
                InfoRow(label: "夏令时", value: manager.systemInfo.isDaylightSaving ? "生效中" : "未生效")
                InfoRow(label: "下次切换", value: manager.environmentInfo.nextDSTTransitionText)
                InfoRow(label: "小数分隔符", value: manager.environmentInfo.decimalSeparator)
                InfoRow(label: "千分位分隔符", value: manager.environmentInfo.groupingSeparator)
            }

            Section("安全与时钟") {
                InfoRow(label: "越狱检测", value: manager.systemInfo.isJailbroken ? "疑似越狱" : "未越狱")
                InfoRow(label: "越狱标记", value: manager.systemInfo.jailbreakMarkers.isEmpty ? "无" : manager.systemInfo.jailbreakMarkers)
                InfoRow(label: "时钟偏差", value: manager.systemInfo.clockSkewText)
            }

            if !manager.errors.isEmpty {
                Section("错误信息") {
                    ForEach(manager.errors, id: \.self) { error in
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("系统信息")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    SystemInfoView()
}
