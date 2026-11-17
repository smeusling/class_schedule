// Views/Components/TopBarView.swift

import SwiftUI

struct TopBarView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            
            // ── Flèche retour HomeView ─────────────────────────────
            Button(action: {
                viewModel.showHomeView = true
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            // ── Volée, modalité et option, semestre (trois lignes) ──
            if let volee = viewModel.selectedVolee {
                VStack(alignment: .leading, spacing: 2) {
                    Text(volee)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(viewModel.currentSemestreName)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                    
                    
                    // Modalité et option ; ligne absente si la volée n'en a pas
                    let details = [viewModel.selectedModaliteLabel, viewModel.selectedOptionLabel].compactMap { $0 }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    
                }
                .layoutPriority(1)
            }
            
            Spacer()
            
            // ── Bouton "Tout" ───────────────────────────────────────
            Button(action: {
                viewModel.showAllCourses.toggle()
            }) {
                Text("Tout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(viewModel.showAllCourses ? Color(red: 116/255, green: 118/255, blue: 216/255) : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(viewModel.showAllCourses ? Color.white : Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // ── Icône toggle vue ───────────────────────────────────
            Button(action: {
                viewModel.selectedView = viewModel.selectedView == .week ? .list : .week
            }) {
                Image(systemName: viewModel.selectedView == .week ? "list.bullet" : "calendar")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 116/255, green: 118/255, blue: 216/255))
    }
}
