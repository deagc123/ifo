//
//  DeviceShareView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI
import Photos

struct DeviceShareView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = DeviceManager.shared
    @State private var isSaving = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var captureTime = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(String(localized: "Close"))
                }
                Spacer()
                Text(String(localized: "Share Device Info"))
                    .font(.headline)
                Spacer()
                Color.clear
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                DeviceShareCard(captureTime: captureTime)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            Button {
                saveToAlbum()
            } label: {
                Label(String(localized: "Save to Photos"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 12)
            .disabled(isSaving)
        }
        .background(Color(.systemGroupedBackground))
        .alert(resultMessage, isPresented: $showResult) {
            Button("OK") {}
        }
    }

    private func saveToAlbum() {
        let renderer = ImageRenderer(content: DeviceShareCard(captureTime: captureTime))
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            resultMessage = String(localized: "Failed to render image")
            showResult = true
            return
        }
        isSaving = true
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    resultMessage = String(localized: "No photo access permission")
                    showResult = true
                    isSaving = false
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            resultMessage = String(localized: "Saved to Photos")
                        } else {
                            resultMessage = error?.localizedDescription ?? String(localized: "Save failed")
                        }
                        showResult = true
                        isSaving = false
                    }
                }
            }
        }
    }
}

struct DeviceShareCard: View {
    @ObservedObject private var manager = DeviceManager.shared
    let captureTime: Date

    private let cardWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text("ifo")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                row("Device Model", value: "\(manager.hardwareInfo.deviceName)（\(manager.deviceInfo.hardwareModel)）")
                row("System Version", value: manager.systemInfo.osVersionString)
                row("CPU", value: cpuText)
                row("Cores", value: coresText)
                row("Resolution", value: manager.screenInfo.nativeBounds)
                row("Screen Size", value: screenText)
                row("Refresh Rate", value: manager.hardwareInfo.refreshRateText)
                row("RAM", value: manager.memoryInfo.totalText)
                row("Storage", value: manager.storageInfo.totalText)
                row("Color Gamut", value: manager.environmentInfo.displayGamut)
                row("Biometrics", value: manager.hardwareInfo.biometricType)
                row("Battery", value: manager.batteryState)
            }
            .padding(16)

            Divider()

            HStack {
                Spacer()
                Text(fullTimeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var cpuText: String {
        let gpu = manager.hardwareInfo.gpuName
        return gpu.isEmpty ? manager.systemInfo.cpuBrandString : gpu
    }

    private var coresText: String {
        let cores = manager.hardwareInfo.physicalCPU > 0
            ? manager.hardwareInfo.physicalCPU
            : manager.systemInfo.processorCount
        let threads = manager.hardwareInfo.logicalCPU > 0
            ? manager.hardwareInfo.logicalCPU
            : manager.systemInfo.activeProcessorCount
        return String(localized: "\(cores) cores / \(threads) threads")
    }

    private var screenText: String {
        let diagonal = manager.hardwareInfo.screenDiagonal
        return diagonal.isEmpty ? "—" : diagonal
    }

    private var fullTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: captureTime)
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    DeviceShareView()
}
