//
//  SplashView.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("ifo")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                Text("Device Info Tool")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SplashView()
}
