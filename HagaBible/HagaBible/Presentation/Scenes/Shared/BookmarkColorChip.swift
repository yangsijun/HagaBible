//
//  BookmarkColorChip.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import SwiftUI

struct BookmarkColorChip: View {
    let color: BookmarkColor
    let isSelected: Bool
    var size: CGFloat = 26
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)
                .overlay(
                    Image(systemName: "checkmark")
                        .bold()
                        .foregroundStyle(.thickMaterial)
                        .opacity(isSelected ? 1 : 0)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 10) {
        ForEach(BookmarkColor.allCases, id: \.self) { color in
            BookmarkColorChip(color: color, isSelected: color == .yellow) {}
        }
    }
    .padding()
}
