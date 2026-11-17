//
//  ScheduleMapper.swift
//  HorairesCours
//
//  Created by Stéphanie Meusling on 17.11.2026.
//

import Foundation

// Convertit les réponses de l'API en CourseSchedule (modèle SwiftData affiché et mis en cache).
// Le modèle CourseSchedule n'est pas modifié (pas de migration SwiftData).
enum ScheduleMapper {

    static func schedules(fromCourses courses: [APICours]) -> [CourseSchedule] {
        let colors = ScheduleColor.allCases
        return courses.enumerated().compactMap { index, course in
            guard let date = date(fromAPI: course.date) else { return nil }
            return CourseSchedule(
                date: date,
                heure: timeRange(course.heureDebut, course.heureFin) ?? "Horaire non précisé",
                cours: course.cours,
                salle: course.salle,
                enseignant: course.enseignant,
                duration: duration(course.heureDebut, course.heureFin),
                color: colors[index % colors.count],
                contenuCours: course.contenuCours,
                nombrePeriode: ""
            )
        }
    }

    static func schedules(fromExams exams: [APIExamen]) -> [CourseSchedule] {
        let colors = ScheduleColor.allCases
        return exams.enumerated().compactMap { index, exam in
            guard let date = date(fromAPI: exam.date) else { return nil }
            let range = timeRange(exam.heureDebut, exam.heureFin)
            let heure: String
            if let arrivee = exam.heureArrivee, let range {
                heure = "Arrivée: \(arrivee) | Examen: \(range)"
            } else if let range {
                heure = range
            } else {
                heure = "À rendre"   // travail à rendre : date limite, sans heure
            }
            return CourseSchedule(
                date: date,
                heure: heure,
                cours: exam.cours,
                salle: exam.salle,
                enseignant: exam.enseignant,
                duration: duration(exam.heureDebut, exam.heureFin),
                color: colors[index % colors.count],
                contenuCours: examDetails(exam),
                nombrePeriode: ""
            )
        }
    }

    // Détail d'un examen rangé dans contenuCours, au format déjà lu par CourseDetailView (lignes 📝, 🔒, 📚).
    private static func examDetails(_ exam: APIExamen) -> String {
        var lines: [String] = []
        if !exam.modaliteExamen.isEmpty { lines.append("📝 \(exam.modaliteExamen)") }
        if !exam.anonymisation.isEmpty { lines.append("🔒 Anonymisation: \(exam.anonymisation)") }
        if isRestrictingOption(exam.option) { lines.append("📚 \(exam.option)") }
        return lines.joined(separator: "\n")
    }

    // "Tous" et "Toutes orientations" concernent tout le monde : pas d'option à afficher.
    private static func isRestrictingOption(_ option: String) -> Bool {
        let normalized = option.trimmingCharacters(in: .whitespaces).lowercased()
        return !normalized.isEmpty && normalized != "tous" && normalized != "toutes orientations"
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // Date AAAA-MM-JJ de l'API → minuit UTC, comme l'ancienne lecture Excel (regroupement par jour inchangé).
    static func date(fromAPI value: String?) -> Date? {
        guard let value else { return nil }
        return apiDateFormatter.date(from: value)
    }

    private static func timeRange(_ debut: String?, _ fin: String?) -> String? {
        guard let debut, let fin else { return nil }
        return "\(debut) - \(fin)"
    }

    // Durée au format de l'app : "3h", "30min", "3h30min" ; vide si incalculable.
    private static func duration(_ debut: String?, _ fin: String?) -> String {
        guard let start = minutes(debut), let end = minutes(fin), end > start else { return "" }
        let total = end - start
        let h = total / 60, m = total % 60
        if h > 0 && m > 0 { return "\(h)h\(m)min" }
        if h > 0 { return "\(h)h" }
        return "\(m)min"
    }

    private static func minutes(_ value: String?) -> Int? {
        guard let parts = value?.split(separator: ":"), parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
