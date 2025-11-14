// Views/Components/BottomDateNavigator.swift

import SwiftUI

struct BottomDateNavigator: View {
    @Binding var selectedDate: Date
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = weekInterval.start
        
        for _ in 0..<7 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDates, id: \.self) { date in
                DateButton(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)) {
                    selectedDate = date
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
