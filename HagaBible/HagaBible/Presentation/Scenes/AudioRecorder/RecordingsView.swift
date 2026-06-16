//
//  RecordingsView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecordingsView: View {
    @State private var viewModel: RecordingsViewModel = DIContainer.shared.resolve(type: RecordingsViewModel.self)
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    @State private var bibleReference = "요한복음 3장 16절"

    @State private var recordingToPlay: Recording?

    @State private var isRenaming = false
    @State private var recordingPendingRename: Recording?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.recordings.isEmpty {
                    Text("No recordings yet.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.recordings) { recording in
                            Button(action: {
                                recordingToPlay = recording
                            }) {
                                VStack(alignment: .leading) {
                                    Text(recording.title)
                                        .font(.headline)
                                }
                            }
                            .contextMenu {
                                Button {
                                    beginRename(recording)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                ShareLink(
                                    item: ShareableRecording(title: recording.title, fileName: recording.fileName),
                                    preview: SharePreview(
                                        recording.title,
                                        icon: Image(uiImage: UIImage(systemName: "waveform")!)
                                    )
                                ) {
                                  Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    beginRename(recording)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteRecording)
                    }
                    .scrollContentBackground(.hidden)
                    .alert("Rename", isPresented: $isRenaming, presenting: recordingPendingRename) { recording in
                        TextField("Title", text: $renameText)
                        Button("Cancel", role: .cancel) {}
                        Button("Save") {
                            viewModel.renameRecording(recording, to: renameText)
                        }
                    }
                    .sheet(item: $recordingToPlay) { recording in
                        RecordingPlayerView(viewModel: viewModel, recording: recording)
                    }
                }
            }
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .safeAreaBar(edge: .bottom, alignment: .center) {
                HStack {
                    VStack(spacing: 8) {
                        if viewModel.isRecording {
                            VStack(spacing: 4) {
                                Text(viewModel.recordingTimeText)
                                    .font(.body)
                                WaveformView(samples: viewModel.recordingSamples)
                                    .frame(height: 150)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 32)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        RecordButton(
                            isRecording: viewModel.isRecording,
                            action: toggleRecording
                        )
                        .glassEffect()
                        .padding()
                    }
                    .animation(.easeInOut, value: viewModel.isRecording)
                }
            }
            .navigationTitle("Recordings")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                EditButton()
            }
        }
    }
    
    private func beginRename(_ recording: Recording) {
        recordingPendingRename = recording
        renameText = recording.title
        // Defer one runloop so a context-menu dismissal completes before the alert
        // presents (works around the SwiftUI context-menu → alert presentation race).
        DispatchQueue.main.async {
            self.isRenaming = true
        }
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
    
    private func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteRecording(at: index)
        }
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: isRecording ? 4 : 30)
                        .fill(.red)
                        .padding(isRecording ? 14 : 4)
                )
        }
        .frame(width: 60, height: 60)
        .glassEffect()
        .animation(.easeInOut, value: isRecording)
    }
}

private struct ShareableRecording: Transferable {
    let title: String
    let fileName: String
    var fileURL: URL {
        FileManager.documentsDirectory.appendingPathComponent(fileName)
    }
    
    /// Maps the (now user-editable) title to a safe single path component for the
    /// shared file's name: replaces path separators / null bytes and clamps length,
    /// so an arbitrary rename can't break or traverse the temp-file path.
    private static func safeFileName(from title: String) -> String {
        let sanitized = title
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clamped = String(sanitized.prefix(200))
        if clamped.isEmpty || clamped == "." || clamped == ".." {
            return "recording"
        }
        return clamped
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { recording in
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(safeFileName(from: recording.title))
                    .appendingPathExtension(recording.fileURL.pathExtension)
                
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                try FileManager.default.copyItem(at: recording.fileURL, to: tempURL)
                
                return tempURL
            }
        )
    }
}



#Preview {
    DIContainer.registerForPreview()
    return RecordingsView()
}
