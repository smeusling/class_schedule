// Views/Components/WeekHeaderView.swift

import SwiftUI

struct WeekHeaderView: View {
    let selectedDate: Date
    
    var weekInfo: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        return "\(year) (week \(weekOfYear))"
    }
    
    var dateRange: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        formatter.locale = Locale(identifier: "en_US")
        
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        let endDay = calendar.component(.day, from: end)
        
        return "\(start) - \(endDay)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekInfo)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Text(dateRange)
                .font(.system(size: 20, weight: .semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
}
