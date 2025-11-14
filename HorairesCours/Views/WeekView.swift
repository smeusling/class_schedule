// Views/WeekView.swift

import SwiftUI

struct WeekView: View {
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
    
    var weekInfo: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: viewModel.selectedDate)
        let year = calendar.component(.year, from: viewModel.selectedDate)
        return "Semaine \(weekOfYear), \(year)"
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
            // En-tête avec info semaine
            VStack(spacing: 4) {
                Text(weekInfo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                
                Text(dateRange)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
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
                        .foregroundColor(.secondary)
                    
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
                                schedules: viewModel.groupedByDate[Calendar.current.startOfDay(for: date)] ?? []
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
                }
            )
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}

// MARK: - Footer avec navigation
struct WeekNavigationFooter: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Bouton Semaine précédente
            Button(action: onPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Précédent")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            
            Divider()
                .frame(height: 30)
            
            // Bouton Semaine suivante
            Button(action: onNext) {
                HStack {
                    Text("Suivant")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
    
    // ✅ AJOUT : Trier les cours par heure de début
    var sortedSchedules: [CourseSchedule] {
        let sorted = schedules.sorted { schedule1, schedule2 in
            // Extraire l'heure de début de chaque cours
            let time1 = extractStartTime(from: schedule1.heure)
            let time2 = extractStartTime(from: schedule2.heure)
            
            // DEBUG
            print("📊 Comparaison: '\(schedule1.heure)' (time: \(time1)) vs '\(schedule2.heure)' (time: \(time2))")
            
            return time1 < time2
        }
        
        // DEBUG: Afficher l'ordre final
        print("✅ Ordre final pour \(dayName):")
        for (index, schedule) in sorted.enumerated() {
            print("  \(index + 1). \(schedule.heure) - \(schedule.cours)")
        }
        
        return sorted
    }
    
    // ✅ FONCTION : Extraire l'heure de début (ex: "09:00 - 13:00" -> 540)
    func extractStartTime(from heureString: String) -> Int {
        // Séparer par " - " pour obtenir l'heure de début
        let components = heureString.components(separatedBy: " - ")
        guard let startTime = components.first?.trimmingCharacters(in: .whitespaces) else {
            print("⚠️ Impossible de parser '\(heureString)'")
            return 0
        }
        
        // Vérifier si c'est au format "HH:MM" ou juste "HH"
        if startTime.contains(":") {
            // Format "HH:MM"
            let timeParts = startTime.components(separatedBy: ":")
            guard timeParts.count == 2,
                  let hours = Int(timeParts[0]),
                  let minutes = Int(timeParts[1]) else {
                print("⚠️ Format HH:MM invalide pour '\(startTime)'")
                return 0
            }
            
            let totalMinutes = hours * 60 + minutes
            print("🕐 '\(startTime)' = \(totalMinutes) minutes")
            return totalMinutes
        } else {
            // Format "HH" (sans minutes)
            guard let hours = Int(startTime) else {
                print("⚠️ Format HH invalide pour '\(startTime)'")
                return 0
            }
            
            let totalMinutes = hours * 60
            print("🕐 '\(startTime)' (sans minutes) = \(totalMinutes) minutes")
            return totalMinutes
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
                        .foregroundColor(.primary)
                }
                .frame(width: 50)
                
                // Nom du jour
                Text(dayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Badge nombre de cours
                if !schedules.isEmpty {
                    Text("\(schedules.count) cours")
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
                    // ✅ UTILISER sortedSchedules au lieu de schedules
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
// MARK: - Cell de cours (reste identique)
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
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Horaire
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(schedule.heure)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if !schedule.duration.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(schedule.duration)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Salle
                if !schedule.salle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(schedule.salle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
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

// MARK: - Vue détail du cours (reste identique)
struct CourseDetailView: View {
    let schedule: CourseSchedule
    @Environment(\.dismiss) private var dismiss
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: schedule.date).capitalized
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // En-tête coloré
                VStack(alignment: .leading, spacing: 12) {
                    Text(schedule.cours)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(formattedDate)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    LinearGradient(
                        colors: [schedule.color.color.opacity(0.8), schedule.color.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                
                // Informations
                VStack(spacing: 16) {
                    DetailRow(icon: "clock.fill", title: "Horaire", value: schedule.heure)
                    
                    if !schedule.duration.isEmpty {
                        DetailRow(icon: "hourglass", title: "Durée", value: schedule.duration)
                    }
                    
                    if !schedule.salle.isEmpty {
                        DetailRow(icon: "mappin.circle.fill", title: "Salle", value: schedule.salle)
                    }
                    
                    if !schedule.enseignant.isEmpty {
                        DetailRow(icon: "person.fill", title: "Enseignant", value: schedule.enseignant)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding()
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}
