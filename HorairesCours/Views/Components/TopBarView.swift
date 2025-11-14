// Views/Components/TopBarView.swift

import SwiftUI

struct TopBarView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                viewModel.changeCursus()
            }) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            Spacer()
            
            if let cursus = $viewModel.selectedCursus {
                Text(cursus)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    Button(type.rawValue) {
                        viewModel.selectedView = type
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedView == type ? Color.blue : Color.clear)//
                    .foregroundColor(.white)
                                        .cornerRadius(6)
                                        .font(.system(size: 14))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    Task { await viewModel.refreshData() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                                }
                                .disabled(viewModel.isLoading)
                            }
                            .padding()
                            .background(Color(red: 0.2, green: 0.25, blue: 0.3))
                        }
                    }

