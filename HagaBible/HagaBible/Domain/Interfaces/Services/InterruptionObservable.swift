//
//  InterruptionObservable.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

/// 오디오 인터럽션 관찰 추상화
protocol InterruptionObservable {
    @discardableResult
    func addInterruptionObserver(handler: @escaping (Notification) -> Void) -> NSObjectProtocol

    func removeObserver(_ observer: NSObjectProtocol)
}
