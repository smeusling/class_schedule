//
//  AllCoursesHeader.swift
//  HorairesCours
//
//  Created by Stéphanie Meusling on 02.09.2026.
//
// Views/Components/AllCoursesHeader.swift

import SwiftUI

struct AllCoursesHeader: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Tous les cours")
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .padding(.bottom, 10)
        .padding(.top, 10)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

