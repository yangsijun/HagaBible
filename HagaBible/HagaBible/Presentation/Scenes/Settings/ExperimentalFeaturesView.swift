//
//  ExperimentalFeaturesView.swift
//  HagaBible
//

import SwiftUI

/// "Labs" sheet — opt-in experimental features. Bound to the shared `AppState`, so
/// flipping a toggle immediately shows/hides the dependent UI: the reader's "Listen"
/// action and the TTS mini player (TTS), the Recordings tab (recording), and the
/// reader's book-style page layout (page turning).
/// Reached from the reader's "Other (…)" toolbar menu.
///
/// Colors match the rest of the app: the themed page background is shown through a
/// transparent form (`.scrollContentBackground(.hidden)` + `.presentationBackground`,
/// like the sibling Font & Themes sheet), and controls use the app accent (`.tint`).
struct ExperimentalFeaturesView: View {
    @Bindable var appState: AppState
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $appState.isTTSEnabled) {
                        featureLabel(
                            title: "Listen",
                            subtitle: "Read the Bible aloud with text-to-speech.",
                            systemImage: "headphones"
                        )
                    }
                    Toggle(isOn: $appState.isRecordingEnabled) {
                        featureLabel(
                            title: "Recordings",
                            subtitle: "Record your voice and play it back.",
                            systemImage: "waveform"
                        )
                    }
                    Toggle(isOn: $appState.isPagedReadingEnabled) {
                        featureLabel(
                            title: "Page Turning",
                            subtitle: "Read like a book, turning pages instead of scrolling.",
                            systemImage: "book.pages"
                        )
                    }
                    Toggle(isOn: $appState.isPagedSpreadEnabled) {
                        featureLabel(
                            title: "Two-Page Spread",
                            subtitle: "In landscape, show two pages side by side like an open book.",
                            systemImage: "book"
                        )
                    }
                    .disabled(!appState.isPagedReadingEnabled)
                } header: {
                    Text("Experimental Features")
                } footer: {
                    Text("These features are experimental and off by default. Turning one off only hides it — your recordings and settings are kept.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Labs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    // Render the confirm button in the label color (not accent) to
                    // match the app's checkmark convention (see BookmarkFormContent).
                    // The override is needed because the sheet's .tint(.accent) —
                    // which colors the feature toggles — would otherwise tint it too.
                    .tint(Color.primary)
                }
            }
        }
        .tint(.accent)
        .presentationBackground(Color(uiColor: fontThemeManager.theme.backgroundColor))
    }

    private func featureLabel(title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return ExperimentalFeaturesView(appState: DIContainer.shared.resolve(type: AppState.self))
}
