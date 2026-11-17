// Models/DataSource.swift

import Foundation

enum DataSourceType: String, Codable, CaseIterable {
    case semestre = "Semestre"
    case examens = "Examens"
}

enum FileType: String, Codable {
    case cours = "Horaire de cours"
    case examens = "Horaire d'examens"
}

enum SemestreType: String, Codable {
    case automne = "Automne"
    case printemps = "Printemps"

    // Semestre présélectionné selon la source (mêmes règles que le site) :
    // cours : printemps de janvier à août, automne de septembre à décembre ;
    // examens : automne de septembre à février (session de janvier), printemps de mars à août.
    static func current(for type: DataSourceType, date: Date = Date()) -> SemestreType {
        let month = Calendar.current.component(.month, from: date)
        switch type {
        case .semestre: return (1...8).contains(month) ? .printemps : .automne
        case .examens:  return (3...8).contains(month) ? .printemps : .automne
        }
    }
}

// Source des horaires choisie par l'étudiant (cours ou examens).
// Les fichiers Excel de l'UNIL sont trouvés et lus par l'API (https://horaires-api.fly.dev).
// Les préférences enregistrées avant la migration contiennent aussi un champ "url" : il est simplement ignoré.
struct DataSource: Codable {
    let type: DataSourceType
    let fileType: FileType

    static let semestre = DataSource(type: .semestre, fileType: .cours)
    static let examens = DataSource(type: .examens, fileType: .examens)

    static func automatic(for type: DataSourceType) -> DataSource {
        switch type {
        case .semestre: return semestre
        case .examens:  return examens
        }
    }
}
