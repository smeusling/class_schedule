// Views/WeekView.swift

import SwiftUI

struct WeekView: View {
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
                    VStack(spacing: 1) {
                        ForEach(weekDays.indices, id: \.self) { index in
                            WeekDayRow(
                                date: weekDays[index],
                                schedules: viewModel.groupedByDate[Calendar.current.startOfDay(for: weekDays[index])] ?? [],
                                isExamen: viewModel.currentFileType == .examens,
                                isLast: index == weekDays.count - 1
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

    // MARK: - Ligne d'un jour

    struct WeekDayRow: View {
        let date: Date
        let schedules: [CourseSchedule]
        let isExamen: Bool
        let isLast: Bool

        var sortedSchedules: [CourseSchedule] {
            schedules.sorted { extractStartTime(from: $0.heure) < extractStartTime(from: $1.heure) }
        }

        func extractStartTime(from heureString: String) -> Int {
            guard let startTime = heureString.components(separatedBy: " - ").first?.trimmingCharacters(in: .whitespaces) else { return 0 }
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
            f.dateFormat = "EEE"
            return f.string(from: date).uppercased()
        }

        var dayNumber: String {
            let f = DateFormatter()
            f.dateFormat = "d"
            return f.string(from: date)
        }

        var isToday: Bool {
            Calendar.current.isDateInToday(date)
        }

        var body: some View {
            HStack(alignment: .top, spacing: 0) {

                // ── Colonne date ───────────────────────────────────
                VStack(spacing: 4) {
                    Text(dayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isToday ? Color(hex: "7B6FE8") : .black)

                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color(hex: "7B6FE8"))
                                .frame(width: 38, height: 38)
                        }
                        Text(dayNumber)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isToday ? .white : .black)
                    }
                }
                .frame(width: 52)
                .padding(.vertical, 12)

                // ── Séparateur ─────────────────────────────────────
//                Rectangle()
//                    .fill(Color.gray.opacity(0.15))
//                    .frame(width: 1)

                // ── Cours ──────────────────────────────────────────
                if schedules.isEmpty {
                    HStack {
                        Text(isExamen ? "Pas d'examen" : "Pas de cours")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "4A4A4A"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(sortedSchedules) { schedule in
                                WeekCourseCard(schedule: schedule)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color.white)

            if !isLast {
                Divider()
            }
                
        }
    }

    // MARK: - Carte de cours

    struct WeekCourseCard: View {
        let schedule: CourseSchedule

        var body: some View {
            NavigationLink(destination: CourseDetailView(schedule: schedule)) {
                VStack(alignment: .leading, spacing: 6) {

                    // Heure + icône
                    Text(schedule.heure)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(1)

                    // Nom du cours
                    Text(schedule.cours)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    // Salle
                    if !schedule.salle.isEmpty {
                        HStack(spacing: 4) {
                            Image("location")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .opacity(0.5)
                            Text(schedule.salle)
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(12)
                .frame(width: 240, alignment: .topLeading)
                .background(schedule.color.color)
                .cornerRadius(14)
                .shadow(color: schedule.color.color.opacity(0.4), radius: 6, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
