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
            Section("Sensor Availability") {
                InfoRow(label: "Available Sensors", value: manager.sensorInfo.availabilityText)
            }

            Section("Motion Data") {
                InfoRow(label: "Accelerometer (g)", value: manager.sensorInfo.accelerometerText)
                InfoRow(label: "Gyroscope (°/s)", value: manager.sensorInfo.gyroText)
                InfoRow(label: "Magnetometer (µT)", value: manager.sensorInfo.magnetometerText)
                InfoRow(label: "User Acceleration", value: manager.sensorInfo.userAccelerationText)
                InfoRow(label: "Rotation Rate", value: manager.sensorInfo.rotationRateText)
                InfoRow(label: "Attitude", value: manager.sensorInfo.attitudeText)

                RealtimeChartCard(
                    title: String(localized: "Accelerometer (g)"),
                    seriesCount: 3,
                    colors: [.red, .green, .blue],
                    interval: 0.1
                ) {
                    guard let v = manager.accelerometerVector() else { return [] }
                    return [centerNorm(v.x, span: 3), centerNorm(v.y, span: 3), centerNorm(v.z, span: 3)]
                }
                RealtimeChartCard(
                    title: String(localized: "Gyroscope (°/s)"),
                    seriesCount: 3,
                    colors: [.red, .green, .blue],
                    interval: 0.1
                ) {
                    guard let v = manager.gyroVector() else { return [] }
                    return [centerNorm(v.x, span: 8), centerNorm(v.y, span: 8), centerNorm(v.z, span: 8)]
                }
                RealtimeChartCard(
                    title: String(localized: "Magnetometer (µT)"),
                    seriesCount: 3,
                    colors: [.red, .green, .blue],
                    interval: 0.1
                ) {
                    guard let v = manager.magnetometerVector() else { return [] }
                    return [centerNorm(v.x, span: 200), centerNorm(v.y, span: 200), centerNorm(v.z, span: 200)]
                }
            }

            Section("Barometer") {
                InfoRow(label: "Relative Altitude", value: manager.sensorInfo.relativeAltitudeText)
                InfoRow(label: "Pressure", value: manager.sensorInfo.pressureText)

                RealtimeChartCard(
                    title: String(localized: "Pressure"),
                    seriesCount: 1,
                    colors: [.accentColor],
                    interval: 1.0
                ) {
                    guard let p = manager.currentPressure() else { return [] }
                    return [min(max((p - 96) / 8, 0), 1)]
                }
            }

            Section("Motion Activity") {
                InfoRow(label: "Current Activity", value: manager.sensorInfo.motionActivityText)
            }

            Section {
                InfoRow(label: "Authorization Status", value: manager.sensorInfo.locationAuthStatus)
                InfoRow(label: "Accuracy", value: manager.sensorInfo.accuracyAuthorizationText)
                InfoRow(label: "Latitude", value: manager.sensorInfo.latitudeText)
                InfoRow(label: "Longitude", value: manager.sensorInfo.longitudeText)
                InfoRow(label: "Altitude", value: manager.sensorInfo.altitudeText)
                InfoRow(label: "Course", value: manager.sensorInfo.courseText)
                InfoRow(label: "Speed", value: manager.sensorInfo.speedText)
                InfoRow(label: "Horizontal Accuracy", value: manager.sensorInfo.horizontalAccuracyText)
            } header: {
                Text(String(localized: "Location"))
            } footer: {
                Text("Location permission is optional — all core features work without it; only location and WiFi data are unavailable.")
            }
        }
        .navigationTitle("Sensors")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }

    private func centerNorm(_ value: Double, span: Double) -> Double {
        min(max((value + span) / (2 * span), 0), 1)
    }
}

#Preview {
    SensorView()
}
