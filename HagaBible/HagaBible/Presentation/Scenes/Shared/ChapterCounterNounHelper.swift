//
//  ChapterCounterNounHelper.swift
//  HagaBible
//
//  Created by 양시준 on 10/18/25.
//

func getChapterCounterNoun(bookCode: String, versionLanguage: String) -> String {
    if versionLanguage != "Korean" {
        return ""
    }
    
    if bookCode == "PSA" {
        return "편"
    }
    
    return "장"
}

func getVerseCounterNoun(versionLanguage: String) -> String {
    if versionLanguage != "Korean" {
        return ""
    }
    
    return "절"
}
