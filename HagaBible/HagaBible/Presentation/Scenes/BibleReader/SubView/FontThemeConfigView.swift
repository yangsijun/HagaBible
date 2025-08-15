//
//  FontThemeConfigView.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

struct FontThemeConfigView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var viewModel: BibleReaderViewModel
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            List {
                FontSizeStepperView(fontSize: $viewModel.fontConfiguration.size)
                LineSpacingStepperView(lineSpacing: $viewModel.fontConfiguration.lineSpacing)
                FontTypeConfigView(fontType: $viewModel.fontConfiguration.type)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

struct FontSizeStepperView: View {
    @Binding var fontSize: Int
    
    var body: some View {
        HStack {
            Text("Font Size:")
            Stepper(
                "\(fontSize)",
                value: $fontSize,
                in: 10...64
            )
        }
    }
}

struct LineSpacingStepperView: View {
    @Binding var lineSpacing: Int
    
    var body: some View {
        HStack {
            Text("Line Spacing:")
            Stepper(
                "\(Int(lineSpacing))",
                value: $lineSpacing,
                in: 0...32
            )
        }
    }
}

struct FontTypeConfigView: View {
    @Binding var fontType: FontType
    
    var body: some View {
        Picker("Font", selection: $fontType) {
            ForEach(FontType.allCases, id: \.self) { fontType in
                Text(fontType.rawValue).tag(fontType)
                    .font(.custom(fontNamePairs[fontType]?[.regular] ?? "", size: 17, relativeTo: .body))
            }
        }
        .pickerStyle(.inline)
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    @Previewable @State var viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    NavigationStack {
        Button(action: { isPresented.toggle() }) {
            Text("present")
        }
        .sheet(isPresented: $isPresented) {
            FontThemeConfigView()
                .environment(viewModel)
                .presentationDetents([.medium])
        }
    }
}
