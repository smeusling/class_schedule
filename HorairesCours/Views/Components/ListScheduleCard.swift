// Views/Components/ListScheduleCard.swift

import SwiftUI

struct ListScheduleCard: View {
    let schedule: CourseSchedule
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(schedule.color.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.cours)
                    .font(.system(size: 15, weight: .medium))
                
                HStack(spacing: 8) {
                    Text(schedule.heure)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    if !schedule.salle.isEmpty {
                        Text(schedule.salle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                if !schedule.enseignant.isEmpty {
                    Text(schedule.enseignant)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
