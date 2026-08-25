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

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    TabView {
                        DeviceInfoView()
                            .tabItem { Label("Device", systemImage: "iphone") }
                        SystemInfoView()
                            .tabItem { Label("System", systemImage: "gearshape.2") }
                        ScreenHardwareView()
                            .tabItem { Label("Screen & Hardware", systemImage: "display") }
                        SensorView()
                            .tabItem { Label("Sensors", systemImage: "waveform.path.ecg") }
                        NavigationStack { MoreView() }
                            .tabItem { Label("More", systemImage: "ellipsis.circle") }
                    }
                    .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}
