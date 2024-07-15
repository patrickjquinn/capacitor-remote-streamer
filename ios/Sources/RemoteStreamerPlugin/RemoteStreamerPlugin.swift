import Capacitor
import AVFoundation

@objc(RemoteStreamerPlugin)
public class RemoteStreamerPlugin: CAPPlugin {
    var player: AVPlayer?
    var timeObserver: Any?
    
    @objc func play(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"),
              let url = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupAudioSession()
        setupNotifications()
        setupTimeObserver()
        
        player?.play()
        notifyListeners("play", data: [:])
        call.resolve()
    }
    
    @objc func pause(_ call: CAPPluginCall) {
        player?.pause()
        notifyListeners("pause", data: [:])
        call.resolve()
    }
    
    @objc func resume(_ call: CAPPluginCall) {
        player?.play()
        notifyListeners("play", data: [:])
        call.resolve()
    }
    
    @objc func seekTo(_ call: CAPPluginCall) {
        guard let position = call.getDouble("position") else {
            call.reject("Invalid position")
            return
        }
        let time = CMTime(seconds: position, preferredTimescale: 1000)
        player?.seek(to: time)
        call.resolve()
    }
    
    @objc func stop(_ call: CAPPluginCall) {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeTimeObserver()
        notifyListeners("stop", data: [:])
        call.resolve()
    }
    
    @objc func setPlaybackRate(_ call: CAPPluginCall) {
        guard let rate = call.getFloat("rate") else {
            call.reject("Invalid rate")
            return
        }
        player?.rate = rate
        call.resolve()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            notifyListeners("pause", data: [:])
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
                    notifyListeners("play", data: [:])
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            player?.pause()
            notifyListeners("pause", data: [:])
        default:
            break
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.notifyListeners("timeUpdate", data: ["currentTime": time.seconds])
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeTimeObserver()
    }
}