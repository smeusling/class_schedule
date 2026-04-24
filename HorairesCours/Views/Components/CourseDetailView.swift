// Views/Components/CourseDetailView.swift

import SwiftUI

struct CourseDetailView: View {
    let schedule: CourseSchedule
    @Environment(\.dismiss) private var dismiss
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: schedule.date).capitalized
    }
    
    // Détecter si c'est un examen (contenuCours contient 📝)
    var isExamen: Bool {
        schedule.contenuCours.contains("📝")
    }
    
    // Sous-titre : modalité pour examens, contenu pour cours
    var subtitle: String {
        if isExamen {
            // Extraire la ligne avec 📝
            let lines = schedule.contenuCours.components(separatedBy: "\n")
            return lines.first(where: { $0.contains("📝") })?
                .replacingOccurrences(of: "📝 ", with: "") ?? ""
        }
        return schedule.contenuCours
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // ── Carte header ───────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    // Image TopBar en fond
                    Image("TopBar")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                        .cornerRadius(20)
                    
                    // Contenu par-dessus
                    VStack(alignment: .leading, spacing: 12) {
                        // Icône
                        ZStack {
                            Image("HoraireCoursIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                        }
                        
                        Spacer()
                        
                        // Titre
                        Text(schedule.cours)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Sous-titre
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Date
                        Text(formattedDate)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: 260, alignment: .topLeading)
                }
                .frame(height: 260)
                .shadow(color: Color(hex: "7B6FE8").opacity(0.4), radius: 12, y: 6)
                
                // ── Informations ───────────────────────────────────
                VStack(spacing: 0) {
                    DetailRow(
                        icon: "clock.fill",
                        iconColor: Color(hex: "7476D8"),
                        title: "Horaire",
                        value: schedule.heure
                    )
                    
                    if !schedule.nombrePeriode.isEmpty {
                        Divider()
                        DetailRow(
                            icon: "number.circle.fill",
                            iconColor: Color(hex: "FFA365"),
                            title: "Nombre de périodes",
                            value: schedule.nombrePeriode
                        )
                    }
                    
                    if !schedule.salle.isEmpty {
                        Divider()
                        DetailRow(
                            icon: "mappin.circle.fill",
                            iconColor: Color(hex: "40B5B2"),
                            title: "Salle",
                            value: schedule.salle
                        )
                    }
                    
                    if !schedule.enseignant.isEmpty {
                        Divider()
                        DetailRow(
                            icon: "person.fill",
                            iconColor: Color(hex: "F57667"),
                            title: "Enseignant",
                            value: schedule.enseignant
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.white)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            ZStack(alignment: .leading) {
                Color(hex: "7B6FE8")
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 50)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.leading, 16)
                }
            }
            .frame(height: 50)
            .background(
                Color(hex: "7B6FE8")
                    .ignoresSafeArea(edges: .top)
            )
        }
    }
}

// MARK: - DetailRow

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
