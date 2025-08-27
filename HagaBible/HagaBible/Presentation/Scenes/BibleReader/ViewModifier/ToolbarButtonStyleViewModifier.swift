//
//  ToolbarButtonStyleViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

enum ToolbarButtonShapeType {
    case circle
    case capsule
    case rectangle
    case roundedRectangle(radius: CGFloat)
}

struct ToolbarButtonStyleViewModifier: ViewModifier {
    let type: ToolbarButtonShapeType
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 44, minHeight: 44, maxHeight: 44)
            .foregroundStyle(Color(.label))
            .background(VisualEffectView(effect: UIBlurEffect(style: .regular)))
            .modifier(ToolbarButtonClipShapeModifier(type: type))
            .overlay(strokeOverlay())
            .shadow(color: Color.gray.opacity(0.2), radius: 8, x: 0, y: 4)
            .buttonStyle(.plain)
    }
    
    private struct ToolbarButtonClipShapeModifier: ViewModifier {
        let type: ToolbarButtonShapeType
        
        func body(content: Content) -> some View {
            switch type {
            case .circle:
                content.clipShape(Circle())
            case .capsule:
                content.clipShape(Capsule(style: .continuous))
            case .rectangle:
                content.clipShape(Rectangle())
            case .roundedRectangle(radius: let radius):
                content.clipShape(RoundedRectangle(cornerRadius: radius))
            }
        }
    }
    
    @ViewBuilder
    private func strokeOverlay() -> some View {
        let gradient = LinearGradient(
            colors: [.white.opacity(0.2), .white.opacity(0.1), .white.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let lineWidth: CGFloat = 0.5
        
        switch type {
        case .circle:
            Circle().stroke(gradient, lineWidth: lineWidth)
        case .capsule:
            Capsule(style: .circular).stroke(gradient, lineWidth: lineWidth)
        case .rectangle:
            Rectangle().stroke(gradient, lineWidth: lineWidth)
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: radius).stroke(gradient, lineWidth: lineWidth)
        }
    }
}

extension View {
    func toolbarButtonStyle(_ type: ToolbarButtonShapeType) -> some View {
        modifier(ToolbarButtonStyleViewModifier(type: type))
    }
}
