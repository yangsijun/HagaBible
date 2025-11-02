//
//  SearchHistoryActionBar.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import SwiftUI

struct SearchHistoryActionBar: View {
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    @State private var showClearSearchHistoryDialog = false
    
    var body: some View {
        ActionBar {
            ActionBarButton(action: { showClearSearchHistoryDialog = true }, systemImage: "trash")
                .alert("검색 기록을 모두 삭제하시겠습니까?", isPresented: $showClearSearchHistoryDialog) {
                    Button("삭제", role: .destructive) {
                        viewModel.clearSearchHistory()
                        viewModel.loadSearchHistory()
                    }
                    Button("취소", role: .cancel) {}
                } message: {
                    Text("이 작업은 되돌릴 수 없습니다.")
                }
        }
    }
}
