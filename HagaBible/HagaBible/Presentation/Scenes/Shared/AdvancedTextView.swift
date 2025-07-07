//
//  AdvancedTextView.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import SwiftUI

struct AdvancedTextView: View {
    private var text: String
    private var font: UIFont
    private var alignment: NSTextAlignment
    private var lineBreakMode: NSLineBreakMode
    @State private var height: CGFloat = .zero

    init(
        _ text: String,
        font: UIFont = .systemFont(ofSize: 17),
        alignment: NSTextAlignment = .natural,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.text = text
        self.font = font
        self.alignment = alignment
        self.lineBreakMode = lineBreakMode
    }

    var body: some View {
        InternalRepresentable(
            text: text,
            font: font,
            alignment: alignment,
            lineBreakMode: lineBreakMode,
            dynamicHeight: $height
        )
            .frame(height: height)
    }

    struct InternalRepresentable: UIViewRepresentable {
        var text: String
        var font: UIFont
        var alignment: NSTextAlignment
        var lineBreakMode: NSLineBreakMode
        @Binding var dynamicHeight: CGFloat

        func makeUIView(context: Context) -> UILabel {
            let label = UILabel()
            label.numberOfLines = 0
            label.font = font
            label.textAlignment = alignment
            label.lineBreakMode = lineBreakMode
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            return label
        }

        func updateUIView(_ uiView: UILabel, context: Context) {
            uiView.text = text
            
            let newSize = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
            
            if dynamicHeight != newSize.height {
                DispatchQueue.main.async {
                    self.dynamicHeight = newSize.height
                }
            }
        }
    }
}

#Preview {
    VStack {
        AdvancedTextView(
            "In the beginning, God created the heavens and the earth.",
            font: UIFont.pretendard(size: 17)
        )
        AdvancedTextView(
            "In the beginning, God created the heavens and the earth.",
            font: UIFont.maruBuri(size: 17)
        )
        AdvancedTextView(
            "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            font: UIFont.pretendard(size: 20),
            alignment: NSTextAlignment.justified,
            lineBreakMode: NSLineBreakMode.byCharWrapping
        )
        AdvancedTextView(
            "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            font: UIFont.maruBuri(size: 20),
            alignment: NSTextAlignment.justified,
            lineBreakMode: NSLineBreakMode.byCharWrapping
        )
    }
}
