//
//  FontThemeConfigView.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

struct FontThemeConfigView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FontThemeManager.self) private var fontThemeManager: FontThemeManager
    @State private var appState = DIContainer.shared.resolve(type: AppState.self)
    var language: String
    
    var body: some View {
        @Bindable var fontThemeManager = fontThemeManager
        let fontTypeBinding = Binding<FontType>(
            get: {
                fontThemeManager.fontConfiguration.type[language, default: .sans]
            },
            set: { newFontType in
                fontThemeManager.fontConfiguration.type[language] = newFontType
            }
        )
        
        NavigationStack {
            List {
                FontSizeStepperView(fontSize: $fontThemeManager.fontConfiguration.size)
                LineSpacingStepperView(lineSpacing: $fontThemeManager.fontConfiguration.lineSpacing)
                FontTypeConfigView(fontType: fontTypeBinding)
                ThemePickerView(theme: $fontThemeManager.theme)
                ScreenWakeConfigView(appState: appState)
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

struct ThemePickerView: View {
    @Binding var theme: Theme
    
    var body: some View {
        Picker("Theme", selection: $theme) {
            ForEach(Theme.allCases, id: \.self) { theme in
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: theme.backgroundColor))
                        .stroke(Color(uiColor: theme.textColor), lineWidth: 1)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text("T")
                                .foregroundStyle(Color(uiColor: theme.textColor))
                        )
                    Text(theme.themeName)
                }
            }
        }
        .pickerStyle(.inline)
    }
}

/// "Screen" section for the Font & Themes sheet: keep the display awake while
/// reading and, optionally, dim it after a period of inactivity. Bound to the
/// shared `AppState`, so changes apply live in the reader (see `ScreenWakeController`).
struct ScreenWakeConfigView: View {
    @Bindable var appState: AppState

    /// (label, seconds) options for the dim delay; `0` means never dim.
    private static let dimOptions: [(label: String, seconds: Int)] = [
        ("Never", 0),
        ("15 sec", 15),
        ("30 sec", 30),
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
    ]

    var body: some View {
        Section {
            Toggle("Keep screen on", isOn: $appState.keepScreenOn)
            if appState.keepScreenOn {
                Picker("Dim after", selection: $appState.screenDimAfterSeconds) {
                    ForEach(Self.dimOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Screen")
        } footer: {
            Text(appState.keepScreenOn
                 ? "The screen stays on while reading. Optionally dim it after a period of inactivity to save power — tap the screen to restore."
                 : "The screen turns off automatically using your device's Auto-Lock setting.")
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    @Previewable @State var viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @Previewable @State var fontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    NavigationStack {
        Button(action: { isPresented.toggle() }) {
            Text("present")
        }
        .sheet(isPresented: $isPresented) {
            FontThemeConfigView(language: viewModel.bibleVersion?.language ?? "English")
                .environment(fontThemeManager)
                .presentationDetents([.medium])
        }
    }
}
