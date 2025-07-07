//
//  TopAnchorViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct TopAnchorReaderViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
//                .onChange(of: viewModel.chapterNum, initial: false) {
//                    proxy.scrollTo("topAnchor", anchor: .top)
//                }
        }
    }
}

struct TopAnchorViewModifier: ViewModifier {
    let topAnchor: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(.top, topAnchor)
    }
}
