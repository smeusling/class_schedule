// Views/Components/TopBarView.swift

import SwiftUI

struct TopBarView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Bouton menu - retour à HomeView
            Button(action: {
                viewModel.showHomeView = true
            }) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            // Volée sélectionnée + Type de source + Option
            if let volee = viewModel.selectedVolee {
                VStack(alignment: .leading, spacing: 2) {
                    Text(volee)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    
                    // ✅ NOUVEAU : Afficher l'option si elle existe
                    if let option = viewModel.selectedOption {
                        Text(option)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Text(viewModel.currentSemestreName)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: 150)  // ✅ Augmenté pour avoir plus de place
            }
            
            Spacer()
            
            // Onglets List et Week
            HStack(spacing: 8) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    Button(type.rawValue) {
                        viewModel.selectedView = type
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedView == type ? Color.blue : Color.clear)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .font(.system(size: 14))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 116/255, green: 118/255, blue: 216/255))
    }
}
