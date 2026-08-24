//
//  SensorView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct SensorView: View {
    @ObservedObject private var manager = DeviceManager.shared

    var body: some View {
        List {
            Section("传感器可用性") {
                InfoRow(label: "可用传感器", value: manager.sensorInfo.availabilityText)
            }

            Section("运动数据") {
                InfoRow(label: "加速度计 (g)", value: manager.sensorInfo.accelerometerText)
                InfoRow(label: "陀螺仪 (°/s)", value: manager.sensorInfo.gyroText)
                InfoRow(label: "磁力计 (µT)", value: manager.sensorInfo.magnetometerText)
                InfoRow(label: "用户加速度", value: manager.sensorInfo.userAccelerationText)
                InfoRow(label: "旋转速率", value: manager.sensorInfo.rotationRateText)
                InfoRow(label: "姿态", value: manager.sensorInfo.attitudeText)
            }

            Section("气压计") {
                InfoRow(label: "相对海拔", value: manager.sensorInfo.relativeAltitudeText)
                InfoRow(label: "气压", value: manager.sensorInfo.pressureText)
            }

            Section("运动状态") {
                InfoRow(label: "当前活动", value: manager.sensorInfo.motionActivityText)
            }

            Section("定位") {
                InfoRow(label: "授权状态", value: manager.sensorInfo.locationAuthStatus)
                InfoRow(label: "定位精度", value: manager.sensorInfo.accuracyAuthorizationText)
                InfoRow(label: "纬度", value: manager.sensorInfo.latitudeText)
                InfoRow(label: "经度", value: manager.sensorInfo.longitudeText)
                InfoRow(label: "海拔", value: manager.sensorInfo.altitudeText)
                InfoRow(label: "航向", value: manager.sensorInfo.courseText)
                InfoRow(label: "速度", value: manager.sensorInfo.speedText)
                InfoRow(label: "水平精度", value: manager.sensorInfo.horizontalAccuracyText)
            }
        }
        .navigationTitle("传感器")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    SensorView()
}
