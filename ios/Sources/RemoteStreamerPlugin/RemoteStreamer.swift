import Foundation

@objc public class RemoteStreamer: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
