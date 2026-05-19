import Foundation
import MediaPlayer
@testable import HagaBible

@MainActor
final class SpyNowPlayingInfoCenter: NowPlayingInfoCenterProtocol {
    enum RecordedCall {
        case updateNowPlayingInfo([String: Any])
        case setPlaybackState(MPNowPlayingPlaybackState)
        case clearNowPlayingInfo
    }

    private(set) var nowPlayingInfoWrites: [[String: Any]] = []
    private(set) var playbackStateWrites: [MPNowPlayingPlaybackState] = []
    private(set) var clearNowPlayingInfoCallCount = 0
    private(set) var recordedCalls: [RecordedCall] = []

    func updateNowPlayingInfo(_ info: [String: Any]) {
        nowPlayingInfoWrites.append(info)
        recordedCalls.append(.updateNowPlayingInfo(info))
    }

    func setPlaybackState(_ state: MPNowPlayingPlaybackState) {
        playbackStateWrites.append(state)
        recordedCalls.append(.setPlaybackState(state))
    }

    func clearNowPlayingInfo() {
        clearNowPlayingInfoCallCount += 1
        recordedCalls.append(.clearNowPlayingInfo)
    }
}
