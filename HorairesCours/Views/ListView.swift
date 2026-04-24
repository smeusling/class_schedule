// Views/ListView.swift

import SwiftUI

struct ListView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var weekDays: [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start else { return [] }
        var monday = weekStart
        if calendar.component(.weekday, from: weekStart) == 1 {
            monday = calendar.date(byAdding: .day, value: 1, to: weekStart)!
        }
        return (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var dateRange: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: weekInterval.start)
        let end = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!
        return "\(start) - \(formatter.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header semaine avec navigation ─────────────────────
            WeekNavigationHeader(viewModel: viewModel)
            if viewModel.schedules.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(viewModel.currentFileType == .examens ? "Aucun examen cette semaine" : "Aucun cours cette semaine")
                        .foregroundColor(.gray)
                    PrimaryButton(title: "Choisir une volée") { viewModel.changeCursus() }
                        .padding(.horizontal, 40)
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
                .background(Color.white)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Section d'un jour

struct DaySection: View {
    let date: Date
    let schedules: [CourseSchedule]
    let isExamen: Bool

    var sortedSchedules: [CourseSchedule] {
        schedules.sorted { extractStartTime(from: $0.heure) < extractStartTime(from: $1.heure) }
    }

    func extractStartTime(from heureString: String) -> Int {
        var timeString = heureString
        if heureString.contains("Examen:"), let range = heureString.range(of: "Examen:") {
            timeString = String(heureString[range.upperBound...])
        }
        guard let startTime = timeString.components(separatedBy: " - ").first?.trimmingCharacters(in: .whitespaces) else { return 0 }
        if startTime.contains(":") {
            let parts = startTime.components(separatedBy: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
            return h * 60 + m
        }
        return (Int(startTime) ?? 0) * 60
    }

    var dayName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE"
        return f.string(from: date).capitalized
    }

    var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    var monthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // En-tête du jour
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(monthName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isToday ? Color(hex: "7B6FE8") : .black)
                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color(hex: "7B6FE8"))
                                .frame(width: 34, height: 34)
                        }
                        Text(dayNumber)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isToday ? .white : .black)
                    }
                }
                .frame(width: 50)

                Text(dayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                if !schedules.isEmpty {
                    let label = schedules.count == 1
                        ? (isExamen ? "examen" : "cours")
                        : (isExamen ? "examens" : "cours")
                    Text("\(schedules.count) \(label)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "7B6FE8"))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)

            // Cours du jour
            if schedules.isEmpty {
                HStack {
                    Spacer()
                    Text(isExamen ? "Pas d'examen" : "Pas de cours")
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

            Divider()
                .padding(.top, 8)
        }
    }
}

// MARK: - Cellule de cours

struct CourseCell: View {
    let schedule: CourseSchedule

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(schedule.color.color)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(schedule.cours)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black.opacity(0.7))
                    Text(schedule.heure)
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.7))
                    if !schedule.duration.isEmpty {
                        Text("•").foregroundColor(.black.opacity(0.7))
                        Text(schedule.duration)
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }

                if !schedule.salle.isEmpty {
                    HStack(spacing: 4) {
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .opacity(0.7)
                        Text(schedule.salle)
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 12)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal)
        .background(Color.white)
    }
}
