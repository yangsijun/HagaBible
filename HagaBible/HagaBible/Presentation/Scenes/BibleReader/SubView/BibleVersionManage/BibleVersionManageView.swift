//
//  BibleVersionManageView.swift
//  HagaBible
//
//  Created by 양시준 on 11/30/25.
//

import SwiftUI

struct BibleVersionManageView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleNavigationViewModel.self) private var bibleNavigationViewModel: BibleNavigationViewModel

    let bibleFileRepository: BibleFileRepository = DIContainer.shared.resolve(type: BibleFileRepository.self)

    @State private var isProcessing: Bool = false
    @State private var processingVersionCode: String?
    @State private var showDeleteConfirmation: Bool = false
    @State private var versionToDelete: BibleVersion?
    
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    var body: some View {
        NavigationStack {
            List {
                ForEach(bibleNavigationViewModel.versionList, id: \.versionCode) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(version.versionName)
                                .font(.body)
                            Text(version.language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if processingVersionCode == version.versionCode {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else if version.isDownloaded {
                            Button {
                                versionToDelete = version
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                Task {
                                    await downloadVersion(version)
                                }
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .navigationTitle("Manage Versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Bible Version", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    versionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    guard let version = versionToDelete else { return }
                    Task {
                        await deleteVersion(version)
                    }
                }
            } message: {
                if let version = versionToDelete {
                    Text("Are you sure you want to delete \(version.versionName)?")
                }
            }
            .disabled(isProcessing)
        }
    }

    private func downloadVersion(_ version: BibleVersion) async {
        isProcessing = true
        processingVersionCode = version.versionCode

        defer {
            isProcessing = false
            processingVersionCode = nil
        }

        do {
            try await bibleFileRepository.downloadAndInstall(version: version)
            await bibleNavigationViewModel.loadVersionList()
        } catch {
            print("Failed to download bible file: \(error)")
        }
    }

    private func deleteVersion(_ version: BibleVersion) async {
        isProcessing = true
        processingVersionCode = version.versionCode
        versionToDelete = nil

        defer {
            isProcessing = false
            processingVersionCode = nil
        }

        do {
            try await bibleFileRepository.delete(version: version)
            await bibleNavigationViewModel.loadVersionList()
        } catch {
            print("Failed to delete bible file: \(error)")
        }
    }
}
