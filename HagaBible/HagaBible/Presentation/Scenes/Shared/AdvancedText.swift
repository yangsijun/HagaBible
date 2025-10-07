//
//  AdvancedText.swift
//  HagaBible
//
//  Created by 양시준 on 8/14/25.
//

import SwiftUI

struct AdvancedText: UIViewRepresentable {
    var attributedText: NSMutableAttributedString
    
    init(attributedText: NSMutableAttributedString) {
        self.attributedText = attributedText
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        textView.isEditable = false
        textView.isScrollEnabled = false
        
        textView.backgroundColor = .clear
        
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.isUserInteractionEnabled = false
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let newSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return newSize
    }
}


extension NSMutableAttributedString {
    func addingAttributes(_ attrs: [NSAttributedString.Key: Any], toSubstring substring: String) -> NSMutableAttributedString {
        if let range = self.string.range(of: substring, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: self.string)
            self.addAttributes(attrs, range: nsRange)
        }
        return self
    }
}


#Preview {
    AdvancedText(
        attributedText: NSMutableAttributedString(
            string: "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            attributes: [
                .font: UIFont.pretendard(size: 20),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .justified
                    style.minimumLineHeight = 27.0
                    style.maximumLineHeight = 27.0
                    return style
                }(),
            ]
        )
    )
}
