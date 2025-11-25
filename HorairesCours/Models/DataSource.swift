// Models/DataSource.swift

import Foundation

enum DataSourceType: String, Codable, CaseIterable {
    case semestreAutomne = "Semestre Automne"
    case examens = "Examens"
    case customURL = "URL Personnalisée"
}

enum FileType: String, Codable {
    case cours = "Horaire de cours"
    case examens = "Horaire d'examens"
}

struct DataSource: Codable {
    let type: DataSourceType
    let url: String
    let fileType: FileType
    
    static let semestreAutomne = DataSource(
        type: .semestreAutomne,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251106_Horaire_Automne_2025.xlsx",
        fileType: .cours
    )
    
    static let examens = DataSource(
        type: .examens,
        url: "https://www.unil.ch/files/live/sites/fbm/files/06-espaces/sciences-infirmieres/20251030_Horaire_Examens_A25.xlsx",
        fileType: .examens
    )
}
