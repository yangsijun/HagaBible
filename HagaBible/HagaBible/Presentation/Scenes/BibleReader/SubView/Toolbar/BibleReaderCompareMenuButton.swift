//
//  BibleReaderCompareMenuButton.swift
//  HagaBible
//
//  Created by 양시준 on 5/22/26.
//

import SwiftUI

/// Top-bar menu for choosing which translation to show beneath each verse
/// (역본 대조 보기). Lists the comparison-eligible versions plus an "off" option,
/// with a checkmark on the active choice. The icon is filled while comparison is on.
struct BibleReaderCompareMenuButton: View {
    let versions: [BibleVersion]
    let selectedVersionCode: String?
    let onSelect: (String?) -> Void

    private var icon: String {
        selectedVersionCode == nil ? "rectangle.split.1x2" : "rectangle.split.1x2.fill"
    }

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                if selectedVersionCode == nil {
                    Label("Off", systemImage: "checkmark")
                } else {
                    Text("Off")
                }
            }
            if !versions.isEmpty {
                Divider()
                ForEach(versions, id: \.versionCode) { version in
                    Button {
                        onSelect(version.versionCode)
                    } label: {
                        if version.versionCode == selectedVersionCode {
                            Label(version.versionName, systemImage: "checkmark")
                        } else {
                            Text(version.versionName)
                        }
                    }
                }
            }
        } label: {
            Label("Compare", systemImage: icon)
        }
        .menuStyle(.button)
    }
}

#Preview {
    NavigationStack {
        Text("Reader")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    BibleReaderCompareMenuButton(
                        versions: [
                            .init(versionCode: "WEBBE", versionName: "World English Bible", versionShortName: "WEBBE", language: "English", isDownloaded: true),
                            .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
                        ],
                        selectedVersionCode: "KRV",
                        onSelect: { _ in }
                    )
                }
            }
    }
}
