// Views/Components/DateButton.swift

import SwiftUI

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date).prefix(3).uppercased()
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Text(dayNumber)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(20)
        }
    }
}
