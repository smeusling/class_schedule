// Views/WeekView.swift

import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    // MARK: - Helpers

    var weekDays: [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start else { return [] }

        // Si le début de semaine tombe un dimanche (weekday == 1), décaler au lundi
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(dateRange)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 2)

                if viewModel.schedules.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(viewModel.currentFileType == .examens ? "Aucun examen cette semaine" : "Aucun cours cette semaine")
                            .foregroundColor(.gray)
                        Button("Choisir une volée") { viewModel.changeCursus() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(weekDays, id: \.self) { date in
                                WeekDayRow(
                                    date: date,
                                    schedules: viewModel.groupedByDate[Calendar.current.startOfDay(for: date)] ?? [],
                                    isExamen: viewModel.currentFileType == .examens
                                )
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                }

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

    // MARK: - Ligne d'un jour

    struct WeekDayRow: View {
        let date: Date
        let schedules: [CourseSchedule]
        let isExamen: Bool

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

        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 4) {
                    Text(dayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(dayNumber)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(width: 60)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)

                if schedules.isEmpty {
                    Text(isExamen ? "Pas d'examen" : "Pas de cours")
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

    // MARK: - Carte de cours

    struct WeekCourseCard: View {
        let schedule: CourseSchedule

        var body: some View {
            NavigationLink(destination: CourseDetailView(schedule: schedule)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schedule.heure)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                    Text(schedule.cours)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !schedule.salle.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.7))
                            Text(schedule.salle)
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.7))
                                .lineLimit(1)
                        }
                    }
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
