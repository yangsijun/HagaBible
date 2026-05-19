//
//  SystemRemoteCommandConfigurator.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import MediaPlayer

final class SystemRemoteCommandConfigurator: RemoteCommandConfigurable {
    func configureCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onNextTrack: @escaping () -> Void,
        onPreviousTrack: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            onTogglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            onNextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            onPreviousTrack()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }
}
