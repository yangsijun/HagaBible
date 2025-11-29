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
    
    @State private var isPlayerPresented = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.recordings.isEmpty {
                    Text("녹음이 없습니다.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.recordings) { recording in
                            Button(action: {
                                // TODO: 녹음파일 재생
                            }) {
                                VStack(alignment: .leading) {
                                    Text(recording.title)
                                        .font(.headline)
                                }
                            }
                            .contextMenu {
                                ShareLink(
                                    item: ShareableRecording(title: recording.title, fileName: recording.fileName),
                                    preview: SharePreview(
                                        recording.title,
                                        icon: Image(uiImage: UIImage(systemName: "waveform")!)
                                    )
                                ) {
                                  Label("공유하기", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .onDelete(perform: deleteRecording)
                    }
                    .scrollContentBackground(.hidden)
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

struct RecordingRow: View {
    let url: URL
    let playAction: () -> Void
    
    var body: some View {
        HStack {
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: playAction) {
                Image(systemName: "play.circle")
                    .font(.system(size: 24))
            }
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
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { recording in
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(recording.title)
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
