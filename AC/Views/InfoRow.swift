//
//  InfoRow.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        InfoRow(label: "Test", value: "Sample")
    }
}
