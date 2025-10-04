//
//  FileManager+Extension.swift
//  HagaBible
//
//  Created by 양시준 on 10/5/25.
//

import Foundation

extension FileManager {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
