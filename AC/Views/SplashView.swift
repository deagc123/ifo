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
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                Text("ifo")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }
        }
    }
}

#Preview {
    SplashView()
}
