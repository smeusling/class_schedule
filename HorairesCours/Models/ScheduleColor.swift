// Models/ScheduleColor.swift

import SwiftUI

enum ScheduleColor: String, Codable, CaseIterable {
    case pink, green, blue, purple, orange, yellow
    
    var color: Color {
        switch self {
        case .pink: return Color(red: 1.0, green: 0.8, blue: 0.9)
        case .green: return Color(red: 0.8, green: 0.95, blue: 0.85)
        case .blue: return Color(red: 0.85, green: 0.9, blue: 1.0)
        case .purple: return Color(red: 0.9, green: 0.85, blue: 1.0)
        case .orange: return Color(red: 1.0, green: 0.9, blue: 0.8)
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.7)
        }
    }
}
