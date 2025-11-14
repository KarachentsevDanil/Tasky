//
//  CalendarTabView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Calendar tab with day/week/month views
struct CalendarTabView: View {
    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var selectedView: CalendarViewType = .day

    // MARK: - View Type
    enum CalendarViewType: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Picker
                Picker("View", selection: $selectedView) {
                    ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                        Text(viewType.rawValue).tag(viewType)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content based on selected view
                Group {
                    switch selectedView {
                    case .day:
                        DayCalendarContent(
                            viewModel: viewModel,
                            timerViewModel: timerViewModel,
                            selectedDate: $selectedDate
                        )
                    case .week:
                        WeekCalendarContent(
                            viewModel: viewModel,
                            timerViewModel: timerViewModel,
                            selectedDate: $selectedDate
                        )
                    case .month:
                        MonthCalendarContent(
                            viewModel: viewModel,
                            timerViewModel: timerViewModel,
                            selectedDate: $selectedDate
                        )
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
