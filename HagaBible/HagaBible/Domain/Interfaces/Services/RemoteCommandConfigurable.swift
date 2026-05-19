//
//  RemoteCommandConfigurable.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

/// 잠금 화면 / 제어 센터 원격 명령 설정 추상화
protocol RemoteCommandConfigurable {
    func configureCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onNextTrack: @escaping () -> Void,
        onPreviousTrack: @escaping () -> Void
    )
}
