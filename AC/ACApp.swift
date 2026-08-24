//
//  ACApp.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceManager.shared.updatePushToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceManager.shared.updatePushError(error)
    }
}

@main
struct ACApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            TabView {
                DeviceInfoView()
                    .tabItem { Label("设备", systemImage: "iphone") }
                SystemInfoView()
                    .tabItem { Label("系统", systemImage: "gearshape.2") }
                ScreenHardwareView()
                    .tabItem { Label("屏幕硬件", systemImage: "display") }
                SensorView()
                    .tabItem { Label("传感器", systemImage: "waveform.path.ecg") }
                BundleInfoView()
                    .tabItem { Label("当前App", systemImage: "app.badge") }
                InstalledAppsView()
                    .tabItem { Label("已安装", systemImage: "square.grid.2x2") }
            }
        }
    }
}
