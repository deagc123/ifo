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
            }

            Section("Barometer") {
                InfoRow(label: "Relative Altitude", value: manager.sensorInfo.relativeAltitudeText)
                InfoRow(label: "Pressure", value: manager.sensorInfo.pressureText)
            }

            Section("Motion Activity") {
                InfoRow(label: "Current Activity", value: manager.sensorInfo.motionActivityText)
            }

            Section("Location") {
                InfoRow(label: "Authorization Status", value: manager.sensorInfo.locationAuthStatus)
                InfoRow(label: "Accuracy", value: manager.sensorInfo.accuracyAuthorizationText)
                InfoRow(label: "Latitude", value: manager.sensorInfo.latitudeText)
                InfoRow(label: "Longitude", value: manager.sensorInfo.longitudeText)
                InfoRow(label: "Altitude", value: manager.sensorInfo.altitudeText)
                InfoRow(label: "Course", value: manager.sensorInfo.courseText)
                InfoRow(label: "Speed", value: manager.sensorInfo.speedText)
                InfoRow(label: "Horizontal Accuracy", value: manager.sensorInfo.horizontalAccuracyText)
            }
        }
        .navigationTitle("Sensors")
        .listStyle(InsetGroupedListStyle())
        .refreshable { manager.refreshAll() }
    }
}

#Preview {
    SensorView()
}
