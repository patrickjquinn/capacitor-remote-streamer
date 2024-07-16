import Foundation
import Capacitor
import AVFoundation

@objc(RemoteStreamerPlugin)
public class RemoteStreamerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "RemoteStreamerPlugin"
    public let jsName = "RemoteStreamer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pause", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "seekTo", returnType: CAPPluginReturnPromise)
    ]
    
    private let implementation = RemoteStreamer()
    
    @objc func play(_ call: CAPPluginCall) {
        guard let url = call.getString("url") else {
            call.reject("Must provide a URL")
            return
        }
        
        implementation.play(url: url) { result in
            switch result {
            case .success:
                call.resolve()
            case .failure(let error):
                call.reject(error.localizedDescription)
            }
        }
    }
    
    @objc func pause(_ call: CAPPluginCall) {
        implementation.pause()
        call.resolve()
    }
    
    @objc func resume(_ call: CAPPluginCall) {
        implementation.resume()
        call.resolve()
    }
    
    @objc func stop(_ call: CAPPluginCall) {
        implementation.stop()
        call.resolve()
    }
    
    @objc func seekTo(_ call: CAPPluginCall) {
        guard let position = call.getDouble("position") else {
            call.reject("Must provide a position")
            return
        }
        
        implementation.seekTo(position: position)
        call.resolve()
    }
}
