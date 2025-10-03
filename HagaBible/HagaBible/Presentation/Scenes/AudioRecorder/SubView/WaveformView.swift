//
//  WaveformView.swift
//  HagaBible
//
//  Created by 양시준 on 8/29/25.
//

import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(samples.indices, id: \.self) { index in
                Capsule()
                    .frame(
                        width: 3,
                        // 샘플 값(0.0 ~ 1.0)에 따라 높이를 조절하고, 최소 높이를 1로 설정
                        height: max(1, CGFloat(samples[index]) * 100)
                    )
                    .foregroundColor(.primary)
            }
        }
        // 샘플 값이 바뀔 때마다 부드러운 애니메이션 효과 적용
//        .animation(.easeOut(duration: 0.05), value: samples)
    }
}

#Preview {
    // 미리보기용 가짜 데이터
    WaveformView(samples: (0..<50).map { _ in CGFloat.random(in: 0.1...1.0) })
        .frame(height: 150)
}
