// Views/ListView.swift

import SwiftUI

struct ListView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.groupedByDate.keys.sorted()), id: \.self) { date in
                    Section {
                        ForEach(viewModel.groupedByDate[date] ?? []) { schedule in
                            ListScheduleCard(schedule: schedule)
                        }
                    } header: {
                        ListSectionHeader(date: date)
                    }
                }
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}
