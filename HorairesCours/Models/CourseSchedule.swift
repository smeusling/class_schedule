// Models/CourseSchedule.swift

import Foundation
import SwiftData

@Model
final class CourseSchedule {
    @Attribute(.unique) var id: UUID
    var date: Date
    var heure: String
    var cours: String
    var salle: String
    var enseignant: String
    var duration: String
    var colorRaw: String
    var contenuCours: String  // ✅ NOUVEAU
    var nombrePeriode: String // ✅ NOUVEAU
    
    var color: ScheduleColor {
        get { ScheduleColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), date: Date, heure: String, cours: String, salle: String, enseignant: String, duration: String, color: ScheduleColor, contenuCours: String = "", nombrePeriode: String = "") {
        self.id = id
        self.date = date
        self.heure = heure
        self.cours = cours
        self.salle = salle
        self.enseignant = enseignant
        self.duration = duration
        self.colorRaw = color.rawValue
        self.contenuCours = contenuCours
        self.nombrePeriode = nombrePeriode
    }
}
