import Foundation
import AVFoundation

class RemoteStreamer: NSObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playbackBufferEmptyObserver: NSKeyValueObservation?
    private var playbackBufferFullObserver: NSKeyValueObservation?
    private var playbackLikelyToKeepUpObserver: NSKeyValueObservation?
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    private var playerStatusObserver: NSKeyValueObservation?
    
    override init() {
        super.init()
        registerForNotifications()
    }
    
    func play(url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "RemoteStreamer", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        player = AVPlayer(playerItem: playerItem)
        setupAudioSession()
        setupObservers(playerItem: playerItem)
        
        player?.playImmediately(atRate: 1.0)
        completion(.success(()))
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
    
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeObservers()
        NotificationCenter.default.post(name: Notification.Name("RemoteStreamerStop"), object: nil)
    }
    
    func seekTo(position: Double) {
        let time = CMTime(seconds: position, preferredTimescale: 1000)
        player?.seek(to: time)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began, take appropriate actions (save state, update user interface)
            print("Audio interruption began")
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Interruption ended, resume playback if needed
                player?.play()
                print("Audio interruption ended, resuming playback")
            }
        }
    }
    
    private func setupObservers(playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        playbackBufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty, options: [.new, .initial]) { item, change in
            if change.newValue == true {
                print("Buffer is empty")
            }
        }
        
        playbackBufferFullObserver = playerItem.observe(\.isPlaybackBufferFull, options: [.new, .initial]) { item, change in
            if change.newValue == true {
                print("Buffer is full")
            }
        }
        
        playbackLikelyToKeepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new, .initial]) { item, change in
            if item.status == .readyToPlay && change.newValue == true {
                print("Playback is likely to keep up")
            }
        }

        playerTimeControlStatusObserver = player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, change in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .paused:
                NotificationCenter.default.post(name: Notification.Name("RemoteStreamerPause"), object: nil)
            case .playing:
                NotificationCenter.default.post(name: Notification.Name("RemoteStreamerPlay"), object: nil)
            case .waitingToPlayAtSpecifiedRate:
                NotificationCenter.default.post(name: Notification.Name("RemoteStreamerBuffering"), object: nil)
                // Handle buffering state if needed
                break
            @unknown default:
                break
            }
        }

        playerStatusObserver = player?.observe(\.status, options: [.new, .initial]) { player, change in
            if player.status == .failed {
                NotificationCenter.default.post(name: Notification.Name("RemoteStreamerStop"), object: nil)
            }
        }
        
        setupTimeObserver()
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        playbackBufferEmptyObserver?.invalidate()
        playbackBufferFullObserver?.invalidate()
        playbackLikelyToKeepUpObserver?.invalidate()
        playerTimeControlStatusObserver?.invalidate()
        playerStatusObserver?.invalidate()
        removeTimeObserver()
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.notifyTimeUpdate(time: time.seconds)
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func notifyTimeUpdate(time: Double) {
        NotificationCenter.default.post(name: Notification.Name("RemoteStreamerTimeUpdate"), object: nil, userInfo: ["currentTime": time])
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        NotificationCenter.default.post(name: Notification.Name("RemoteStreamerStop"), object: nil)
    }
    
    deinit {
        removeObservers()
    }
}
