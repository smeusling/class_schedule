// Views/Components/ScheduleCardCompact.swift

import SwiftUI

struct ScheduleCardCompact: View {
    let schedule: CourseSchedule
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.cours)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if !schedule.enseignant.isEmpty {
                    Text(schedule.enseignant)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 4) {
                    Text(schedule.heure)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    if !schedule.duration.isEmpty {
                        Text(schedule.duration)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(schedule.color.color)
            .cornerRadius(6)
        }
    }
}
