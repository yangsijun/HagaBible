//
//  BibleReaderCompareMenuButton.swift
//  HagaBible
//
//  Created by 양시준 on 5/22/26.
//

import SwiftUI

/// The selectable options for translation comparison (역본 대조 보기): an "Off"
/// row plus every comparison-eligible version, each carrying a checkmark on the
/// active choice. Rendered as the content of the "Compare" submenu inside the
/// reader's "more" menu.
struct BibleReaderCompareMenuItems: View {
    let versions: [BibleVersion]
    let selectedVersionCode: String?
    let onSelect: (String?) -> Void

    var body: some View {
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
    }
}

#Preview {
    NavigationStack {
        Text("Reader")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Menu {
                        BibleReaderCompareMenuItems(
                            versions: [
                                .init(versionCode: "WEBBE", versionName: "World English Bible", versionShortName: "WEBBE", language: "English", isDownloaded: true),
                                .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
                            ],
                            selectedVersionCode: "KRV",
                            onSelect: { _ in }
                        )
                    } label: {
                        Label("Compare", systemImage: "rectangle.split.1x2.fill")
                    }
                }
            }
    }
}
