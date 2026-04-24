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
            
            // ── Volée + option + semestre ──────────────────────────
            if let volee = viewModel.selectedVolee {
                VStack(alignment: .leading, spacing: 2) {
                    Text(volee)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let option = viewModel.selectedOption {
                            Text(option)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                            
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Text(viewModel.currentSemestreName)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
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
