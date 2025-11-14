// Views/Components/DayRowView.swift

import SwiftUI

struct DayRowView: View {
    let date: Date
    let schedules: [CourseSchedule]
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date).capitalized
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                Text(dayNumber)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 50)
            
            if schedules.isEmpty {
                Spacer()
            } else {
                VStack(spacing: 8) {
                    ForEach(schedules) { schedule in
                        ScheduleCardCompact(schedule: schedule)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
