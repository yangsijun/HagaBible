//
//  Theme.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

struct Theme {
    var textColor: UIColor
    var backgroundColor: UIColor
}

let defaultTheme = Theme(
    textColor: UIColor.label,
    backgroundColor: UIColor.systemBackground
)

let darkTheme = Theme(
    textColor: UIColor.white,
    backgroundColor: UIColor.black
)
