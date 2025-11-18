// Views/WeekView.swift

import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    // Obtenir les dates de la semaine (Lundi à Vendredi uniquement)
    var weekDays: [Date] {
        let calendar = Calendar.current
        
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start else {
            return []
        }
        
        var monday = weekStart
        let weekday = calendar.component(.weekday, from: weekStart)
        
        if weekday == 1 {
            monday = calendar.date(byAdding: .day, value: 1, to: weekStart)!
        }
        
        var dates: [Date] = []
        for i in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: i, to: monday) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    // Dans WeekView.swift, modifie weekInfo et dateRange
    
    var dateRange: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        let endFormatted = formatter.string(from: end)
        
        return "\(start) - \(endFormatted)" // ✅ Juste les dates
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête avec info semaine
            VStack(spacing: 4) {
                Text(dateRange)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
                
                // Liste des jours en lignes horizontales
                if viewModel.schedules.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Aucun cours cette semaine")
                            .foregroundColor(.secondary)
                        
                        Button("Choisir une volée") {
                            viewModel.changeCursus()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(weekDays, id: \.self) { date in
                                WeekDayRow(
                                    date: date,
                                    schedules: viewModel.groupedByDate[Calendar.current.startOfDay(for: date)] ?? []
                                )
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                }
                
                // Footer avec navigation semaine
                WeekNavigationFooter(
                    onPrevious: {
                        viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    },
                    onNext: {
                        viewModel.selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    },
                    viewModel: viewModel
                )
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        
        
    }
    
    // MARK: - Ligne d'un jour (row horizontale)
    struct WeekDayRow: View {
        let date: Date
        let schedules: [CourseSchedule]
        
        var sortedSchedules: [CourseSchedule] {
            schedules.sorted { schedule1, schedule2 in
                let time1 = extractStartTime(from: schedule1.heure)
                let time2 = extractStartTime(from: schedule2.heure)
                return time1 < time2
            }
        }
        
        func extractStartTime(from heureString: String) -> Int {
            let components = heureString.components(separatedBy: " - ")
            guard let startTime = components.first?.trimmingCharacters(in: .whitespaces) else {
                return 0
            }
            
            if startTime.contains(":") {
                let timeParts = startTime.components(separatedBy: ":")
                guard timeParts.count == 2,
                      let hours = Int(timeParts[0]),
                      let minutes = Int(timeParts[1]) else {
                    return 0
                }
                return hours * 60 + minutes
            } else {
                guard let hours = Int(startTime) else {
                    return 0
                }
                return hours * 60
            }
        }
        
        var dayName: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "EEE"
            return formatter.string(from: date).uppercased()
        }
        
        var dayNumber: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }
        
        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                // Colonne de la date (à gauche)
                VStack(spacing: 4) {
                    Text(dayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text(dayNumber)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(width: 60)
                .padding(.vertical, 12)
                
                // Séparateur vertical
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                
                // Cours en scrollview horizontale
                if schedules.isEmpty {
                    Text("Pas de cours")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedSchedules) { schedule in
                                WeekCourseCard(schedule: schedule)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color.white)
        }
    }
    
    // MARK: - Carte de cours (version horizontale compacte)
    struct WeekCourseCard: View {
        let schedule: CourseSchedule
        
        var body: some View {
            NavigationLink(destination: CourseDetailView(schedule: schedule)) {
                VStack(alignment: .leading, spacing: 6) {
                    // Horaire
                    Text(schedule.heure)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Nom du cours
                    Text(schedule.cours)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Salle
                    if !schedule.salle.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text(schedule.salle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Enseignant
                    if !schedule.enseignant.isEmpty {
                        Text(schedule.enseignant)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .frame(width: 160, alignment: .topLeading)
                .background(schedule.color.color)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
