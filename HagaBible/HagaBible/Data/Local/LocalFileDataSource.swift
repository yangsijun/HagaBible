//
//  LocalFileDataSource.swift
//  HagaBible
//
//  Created by 양시준 on 11/29/25.
//

//import Foundation
//
//class LocalFileDataSource {
//    private let fileManager = FileManager.default
//    
//    func moveODRFileToDocuments(from srcUrl: URL, versionCode: String) throws -> String {
//        let docUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let destUrl = docUrl.appendingPathComponent("Bible_\(versionCode).sqlite")
//        
//        if fileManager.fileExists(atPath: destUrl.path) {
//            try fileManager.removeItem(at: destUrl)
//        }
//        try fileManager.copyItem(at: srcUrl, to: destUrl)
//        return destUrl.path
//    }
//    
//    func removeFile(versionCode: String) throws {
//        let docUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let destUrl = docUrl.appendingPathComponent("Bible_\(versionCode).sqlite")
//        try fileManager.removeItem(at: destUrl)
//    }
//    
//    func getFilePath(versionCode: String) -> String {
//        let docUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        return docUrl.appendingPathComponent("Bible_\(versionCode).sqlite").path
//    }
//}
