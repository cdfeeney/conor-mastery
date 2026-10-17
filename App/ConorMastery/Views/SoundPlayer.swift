import AVFoundation

/// Reward sounds from the Ninja Adventure pack (CC0): coin on a reward, power-up on a drop, jingle on a level-up.
/// Ambient session, so it mixes with your music and respects the silent switch.
@MainActor
enum SoundPlayer {
    enum Effect: String { case coin, powerup, levelup }

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var isSessionReady = false

    static func play(_ effect: Effect) {
        if !isSessionReady {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            isSessionReady = true
        }
        if players[effect] == nil, let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            players[effect] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
