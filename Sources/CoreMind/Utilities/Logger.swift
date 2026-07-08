import Foundation
import OSLog

enum Log {
    private static let osLog = OSLog(subsystem: Constants.appBundleID, category: Constants.appName)

    private static func log(_ type: OSLogType, _ message: String) {
        #if DEBUG
        os_log(type, log: osLog, "%{public}@", message)
        #else
        os_log(type, log: osLog, "%{private}@", message)
        #endif
    }

    static func info(_ message: String) {
        log(.info, message)
    }

    static func warning(_ message: String) {
        log(.default, message)
    }

    static func error(_ message: String) {
        log(.error, message)
    }
}
