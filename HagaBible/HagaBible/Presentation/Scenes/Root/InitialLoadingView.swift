//
//  InitialLoadingView.swift
//  HagaBible
//
//  Created by 양시준 on 12/31/25.
//

import SwiftUI

struct InitialLoadingView: View {
    let progressText: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("HagaBible")
                    .font(.title)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(progressText.isEmpty ? "Preparing..." : progressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    InitialLoadingView(progressText: "Downloading King James Version... (1/2)")
}
