// Utils/LogManager.swift

import Foundation
import UIKit

class LogManager {
    static let shared = LogManager()
    private var logs: [String] = []
    private let maxLogs = 500
    
    private init() {}
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        logs.append(entry)
        if logs.count > maxLogs { logs.removeFirst() }
        Swift.print(entry) // ← Swift.print() au lieu de print()
    }
    
    func getLogs() -> String {
        logs.joined(separator: "\n")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func getDeviceInfo() -> String {
        let device = UIDevice.current
        return """
        📱 Appareil: \(device.model)
        📱 iOS: \(device.systemVersion)
        📱 Nom: \(device.name)
        📦 App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
        """
    }
}
