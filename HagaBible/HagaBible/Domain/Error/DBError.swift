//
//  DBError.swift
//  HagaBible
//
//  Created by 양시준 on 7/5/25.
//

enum DBError: Error {
    case failedToOpenDatabase
    case failedToSelectData
    case failedToExecuteSQL(String)
    case notFoundVersion
    case notFoundBook
    case notFoundChapter
    case notFoundVerse
}
