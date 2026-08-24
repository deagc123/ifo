//
//  InfoRow.swift
//  AC
//
//  Created by B on 2026/8/20.
//

import SwiftUI

struct InfoRow: View {
    let label: String
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
        InfoRow(label: "测试", value: "示例值")
    }
}
