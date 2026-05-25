//
//  LibrarySection.swift
//  HagaBible
//
//  Created by 양시준 on 5/25/26.
//

/// The two segments of the Library tab: the bookmark list and the 성경읽기표
/// reading checklist. Shared (like `TabIdentifier`) so `AppState` can route the
/// reader's toolbar actions to a specific segment.
enum LibrarySection: Hashable {
    case bookmarks
    case reading
}
