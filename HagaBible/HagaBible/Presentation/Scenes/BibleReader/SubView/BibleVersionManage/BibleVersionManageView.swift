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

    @State private var viewModel = DIContainer.shared.resolve(type: BibleVersionStoreViewModel.self)

    @State private var showDeleteConfirmation: Bool = false
    @State private var versionToDelete: BibleVersionItem?

    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.version.versionName)
                                .font(.body)
                            Text(item.version.language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        accessory(for: item)
                    }
                    .contentShape(Rectangle())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .navigationTitle("Manage Versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restore") {
                        Task { await viewModel.restore() }
                    }
                    .disabled(viewModel.isProcessing)
                }
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
                    guard let item = versionToDelete else { return }
                    Task { await performDelete(item) }
                }
            } message: {
                if let item = versionToDelete {
                    Text("Are you sure you want to delete \(item.version.versionName)?")
                }
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .disabled(viewModel.isProcessing)
            .overlay {
                if viewModel.isRestoring {
                    ProgressView("Restoring…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bibleVersionEntitlementsChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    // MARK: - Row accessory

    @ViewBuilder
    private func accessory(for item: BibleVersionItem) -> some View {
        if viewModel.processingVersionCode == item.version.versionCode {
            ProgressView()
                .frame(width: 24, height: 24)
        } else if item.isDownloaded {
            Button {
                versionToDelete = item
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else {
            switch item.availability {
            case .locked(let displayPrice):
                // Paid and not owned — buying triggers purchase, then download.
                Button {
                    Task { await performAcquire(item) }
                } label: {
                    Text(displayPrice.isEmpty ? String(localized: "Buy") : displayPrice)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

            case .free, .purchased:
                // Free, or paid-and-owned — just download.
                Button {
                    Task { await performAcquire(item) }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func performAcquire(_ item: BibleVersionItem) async {
        await viewModel.acquire(item)
        await bibleNavigationViewModel.loadVersionList()
    }

    private func performDelete(_ item: BibleVersionItem) async {
        versionToDelete = nil
        await viewModel.delete(item)
        await bibleNavigationViewModel.loadVersionList()
    }
}
