// Views/ListView.swift

import SwiftUI

struct ListView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    // Obtenir les dates de la semaine (Lundi à Vendredi uniquement)
    var weekDays: [Date] {
        let calendar = Calendar.current
        
        // Obtenir le début de la semaine
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start else {
            return []
        }
        
        // Trouver le lundi de cette semaine
        var monday = weekStart
        let weekday = calendar.component(.weekday, from: weekStart)
        
        // weekday: 1=Dimanche, 2=Lundi, 3=Mardi, etc.
        if weekday == 1 { // Si c'est dimanche, avancer d'un jour
            monday = calendar.date(byAdding: .day, value: 1, to: weekStart)!
        }
        
        // Générer Lundi à Vendredi (5 jours)
        var dates: [Date] = []
        for i in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: i, to: monday) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
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
        
        return "\(start) - \(endFormatted)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête avec les dates de la semaine
            Text(dateRange)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
            
            // Liste des jours
            if viewModel.schedules.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Aucun cours cette semaine")
                        .foregroundColor(.gray)
                    
                    Button("Choisir une volée") {
                        viewModel.changeCursus()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { date in
                            DaySection(
                                date: date,
                                schedules: viewModel.groupedByDate[Calendar.current.startOfDay(for: date)] ?? [],
                                isExamen: viewModel.currentFileType == .examens
                            )
                        }
                    }
                    .padding(.bottom, 80)
                }
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

// MARK: - Footer avec navigation
struct WeekNavigationFooter: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    @ObservedObject var viewModel: ScheduleViewModel
    
    // Date de la semaine précédente
    var previousWeekRange: String {
        let calendar = Calendar.current
        guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: previousWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        let endFormatted = formatter.string(from: end)
        
        return "\(start) - \(endFormatted)"
    }
    
    // Date de la semaine suivante
    var nextWeekRange: String {
        let calendar = Calendar.current
        guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        let endFormatted = formatter.string(from: end)
        
        return "\(start) - \(endFormatted)"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Bouton Semaine précédente
            Button(action: onPrevious) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(previousWeekRange)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
            
            Divider()
                .frame(height: 30)
            
            // Bouton Semaine suivante
            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text(nextWeekRange)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
    }
}

// MARK: - Section pour un jour
struct DaySection: View {
    let date: Date
    let schedules: [CourseSchedule]
    let isExamen: Bool
    
    // Trier les cours par heure de début
    var sortedSchedules: [CourseSchedule] {
        schedules.sorted { schedule1, schedule2 in
            let time1 = extractStartTime(from: schedule1.heure)
            let time2 = extractStartTime(from: schedule2.heure)
            return time1 < time2
        }
    }
    
    // Extraire l'heure de début (ex: "09:00 - 13:00" -> 540)
    func extractStartTime(from heureString: String) -> Int {
        // Gérer le format spécial des examens "Arrivée: 13:30 | Examen: 14:00 - 17:00"
        var timeString = heureString
        
        if heureString.contains("Examen:") {
            // Extraire l'heure après "Examen:"
            if let examenRange = heureString.range(of: "Examen:") {
                timeString = String(heureString[examenRange.upperBound...])
            }
        }
        
        let components = timeString.components(separatedBy: " - ")
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
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête du jour
            HStack(spacing: 12) {
                // Badge de date
                VStack(spacing: 2) {
                    Text(monthName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(dayNumber)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(width: 50)
                
                // Nom du jour
                Text(dayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Badge nombre de cours/examens
                if !schedules.isEmpty {
                    let label = schedules.count == 1
                        ? (isExamen ? "examen" : "cours")
                        : (isExamen ? "examens" : "cours")
                    
                    Text("\(schedules.count) \(label)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)
            
            // Liste des cours (TRIÉS par heure)
            if schedules.isEmpty {
                HStack {
                    Spacer()
                    Text("Pas de cours")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color.white)
            } else {
                VStack(spacing: 1) {
                    ForEach(sortedSchedules) { schedule in
                        NavigationLink(destination: CourseDetailView(schedule: schedule)) {
                            CourseCell(schedule: schedule)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Séparateur entre les jours
            Rectangle()
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                .frame(height: 8)
        }
    }
}

// MARK: - Cell de cours
struct CourseCell: View {
    let schedule: CourseSchedule
    
    var body: some View {
        HStack(spacing: 12) {
            // Barre de couleur
            Rectangle()
                .fill(schedule.color.color)
                .frame(width: 4)
            
            // Contenu
            VStack(alignment: .leading, spacing: 6) {
                // Nom du cours
                Text(schedule.cours)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                // Horaire
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(schedule.heure)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    if !schedule.duration.isEmpty {
                        Text("•")
                            .foregroundColor(.gray)
                        Text(schedule.duration)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                // Salle
                if !schedule.salle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(schedule.salle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
            
            // Flèche
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal)
        .background(Color.white)
    }
}
