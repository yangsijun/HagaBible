//
//  HalfSheetPresentation.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import SwiftUI

/// A medium/large detent sheet that keeps the Liquid Glass transparent background
/// at `.medium` and switches to a themed solid background at `.large`.
struct HalfSheetPresentation: ViewModifier {
    @Binding var detent: PresentationDetent
    let themeBackgroundColor: UIColor

    func body(content: Content) -> some View {
        content
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationBackground {
                if detent == .medium {
                    Rectangle().fill(.clear)
                } else {
                    Color(uiColor: themeBackgroundColor)
                }
            }
    }
}

extension View {
    func halfSheetPresentation(
        detent: Binding<PresentationDetent>,
        themeBackgroundColor: UIColor
    ) -> some View {
        modifier(HalfSheetPresentation(detent: detent, themeBackgroundColor: themeBackgroundColor))
    }
}
