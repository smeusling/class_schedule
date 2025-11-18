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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // En-tête coloré avec titre, contenu et date
                VStack(alignment: .leading, spacing: 12) {
                    // Titre du cours
                    Text(schedule.cours)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Contenu du cours (en dessous du titre)
                    if !schedule.contenuCours.isEmpty {
                        Text(schedule.contenuCours)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Date (en bas)
                    Text(formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 4)
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
                
                // Informations (sans durée)
                VStack(spacing: 16) {
                    DetailRow(icon: "clock.fill", title: "Horaire", value: schedule.heure)
                    
                    // ❌ SUPPRIMÉ : Durée
                    // if !schedule.duration.isEmpty {
                    //     DetailRow(icon: "hourglass", title: "Durée", value: schedule.duration)
                    // }
                    
                    if !schedule.nombrePeriode.isEmpty {
                        DetailRow(icon: "number.circle.fill", title: "Nombre de périodes", value: schedule.nombrePeriode)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Retour")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
