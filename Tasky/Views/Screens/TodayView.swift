//
//  TodayView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Enhanced Today view with prioritization and completion tracking
struct TodayView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()

    // MARK: - State
    @State private var showConfetti = false
    @State private var celebrationMessage = ""
    @State private var quickTaskTitle = ""
    @State private var sheetPresentation: SheetType?
    @FocusState private var isQuickAddFocused: Bool

    enum SheetType: Identifiable {
        case addTask
        case taskDetail(TaskEntity)
        case focusTimer(TaskEntity)

        var id: String {
            switch self {
            case .addTask: return "addTask"
            case .taskDetail(let task): return "taskDetail-\(task.id)"
            case .focusTimer(let task): return "focusTimer-\(task.id)"
            }
        }
    }

    // MARK: - Computed Properties
    private var todayTasks: [TaskEntity] {
        viewModel.tasks.filter { !$0.isCompleted }
            .sorted { task1, task2 in
                // First sort by due date (tasks with earlier dates come first)
                let date1 = task1.scheduledTime ?? task1.dueDate ?? Date.distantFuture
                let date2 = task2.scheduledTime ?? task2.dueDate ?? Date.distantFuture

                if date1 != date2 {
                    return date1 < date2
                }

                // Then sort by priority (higher priority comes first)
                return task1.priority > task2.priority
            }
    }

    private var completedTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.isCompleted }
    }

    private var completionCount: Int {
        completedTasks.count
    }

    private var totalCount: Int {
        viewModel.tasks.count
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Compact Progress Bar
                    compactProgressBar

                    // Priority Tasks Section - always show to allow quick add
                    priorityTasksSection

                    // Completed Tasks Section
                    if !completedTasks.isEmpty {
                        completedTasksSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Empty State
                    if todayTasks.isEmpty && completedTasks.isEmpty {
                        emptyStateView
                            .transition(.opacity)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: todayTasks.count)
                .animation(.easeInOut(duration: 0.3), value: completedTasks.count)
            }
            .navigationTitle("Today")
            .sheet(item: $sheetPresentation) { sheet in
                switch sheet {
                case .addTask:
                    AddTaskView(viewModel: viewModel)
                case .taskDetail(let task):
                    NavigationStack {
                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                    }
                case .focusTimer(let task):
                    FocusTimerFullView(viewModel: timerViewModel, task: task, onDismiss: {
                        sheetPresentation = nil
                    })
                }
            }
            .confetti(isPresented: $showConfetti)
            .task {
                viewModel.currentFilter = .today
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Compact Progress Bar
    private var compactProgressBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text(motivationalTitle)
                    .font(.headline)
                Spacer()
                Text(motivationalSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * CGFloat(completionCount) / CGFloat(max(totalCount, 1)), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: completionCount)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Priority Tasks Section
    private var priorityTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.title2.weight(.bold))

                Spacer()
            }
            .padding(.horizontal, 4)

            List {
                // Quick Add Row - Always visible
                HStack(spacing: 10) {
                    // Plus icon in blue circle
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 26, height: 26)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    TextField("New Task", text: $quickTaskTitle)
                        .focused($isQuickAddFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addQuickTask()
                        }

                    if !quickTaskTitle.isEmpty {
                        Button {
                            addQuickTask()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Three-dot menu for advanced options
                        Button {
                            HapticManager.shared.lightImpact()
                            sheetPresentation = .addTask
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                ForEach(todayTasks) { task in
                    EnhancedTaskRowView(
                        task: task,
                        timerViewModel: timerViewModel,
                        onToggleCompletion: {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTask(task)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                    .onTapGesture {
                        sheetPresentation = .taskDetail(task)
                    }
                }
                .onMove { from, to in
                    moveTasks(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: max(CGFloat(todayTasks.count + 1) * 70, 70))
            .id(todayTasks.map { "\($0.id)-\($0.isCompleted)" }.joined())
        }
    }

    // MARK: - Completed Tasks Section
    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(completedTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            List {
                ForEach(completedTasks) { task in
                    EnhancedTaskRowView(
                        task: task,
                        timerViewModel: timerViewModel,
                        onToggleCompletion: {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTask(task)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        sheetPresentation = .taskDetail(task)
                    }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: CGFloat(completedTasks.count) * 70)
            .id(completedTasks.map { "\($0.id)-\($0.isCompleted)" }.joined())
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)

            Text("All Done!")
                .font(.title2.weight(.bold))

            Text("You've completed all your tasks for today.\nTake a well-deserved break!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Methods

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var tasks = todayTasks
        tasks.move(fromOffsets: source, toOffset: destination)

        // Update priority order
        Task {
            await viewModel.reorderTasks(tasks)
            HapticManager.shared.selectionChanged()
        }
    }

    private func addQuickTask() {
        let trimmedTitle = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        Task {
            // Create task with today's due date
            await viewModel.createTask(
                title: trimmedTitle,
                dueDate: Calendar.current.startOfDay(for: Date()),
                priority: 0
            )

            // Reset quick add state
            await MainActor.run {
                quickTaskTitle = ""
                HapticManager.shared.success()
            }
        }
    }

    private func toggleTaskCompletion(_ task: TaskEntity) async {
        let wasCompleted = task.isCompleted

        // Toggle completion
        await viewModel.toggleTaskCompletion(task)

        // Haptic and visual feedback
        await MainActor.run {
            if !wasCompleted {
                celebrateCompletion()
            } else {
                HapticManager.shared.mediumImpact()
            }
        }
    }

    private func celebrateCompletion() {
        // Haptic feedback
        HapticManager.shared.success()

        // Show confetti
        showConfetti = true

        // Update motivational message
        celebrationMessage = celebrationMessages.randomElement() ?? "Great job!"
    }

    // MARK: - Motivational Copy
    private var motivationalTitle: String {
        if completionCount == 0 {
            return "Let's get started!"
        } else if completionCount == totalCount && totalCount > 0 {
            return "All done for today!"
        } else {
            return "Keep it up!"
        }
    }

    private var motivationalSubtitle: String {
        if totalCount == 0 {
            return "No tasks yet"
        } else if completionCount == totalCount {
            return "All tasks completed!"
        } else {
            let tasksLeft = totalCount - completionCount
            return "\(tasksLeft) task\(tasksLeft == 1 ? "" : "s") left"
        }
    }

    private let celebrationMessages = [
        "Great work!",
        "You're on fire!",
        "Awesome!",
        "Well done!",
        "Keep going!",
        "Crushing it!",
        "Amazing!",
        "You're unstoppable!"
    ]
}

// MARK: - Enhanced Task Row
struct EnhancedTaskRowView: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Priority Accent Bar (left edge)
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 4)
                    .opacity(task.isCompleted ? 0.4 : 1.0)
            }

            HStack(spacing: 10) {
                // Completion Button
                Button(action: onToggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                // Task Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title Row with timer indicator
                    HStack(alignment: .center, spacing: 8) {
                        Text(task.title)
                            .font(.body)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .lineLimit(2)

                        Spacer(minLength: 4)

                        // Small timer icon indicator (only when timer is active for this task)
                        if isTimerActive {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    // Metadata Pills - Prioritize time information
                    if hasMetadata {
                        HStack(spacing: 6) {
                            // Scheduled Time/Due Date - MOST PROMINENT (shown first, larger)
                            if let formattedTime = task.formattedScheduledTime {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                    Text(formattedTime)
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .opacity(task.isCompleted ? 0.5 : 1.0)
                            }

                            // Priority Pill - With icon for better visibility
                            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                                HStack(spacing: 3) {
                                    Image(systemName: "flag.fill")
                                        .font(.caption2)
                                    Text(priority.displayName)
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(priority.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(priority.color.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .stroke(priority.color.opacity(0.4), lineWidth: 1.5)
                                        )
                                )
                                .opacity(task.isCompleted ? 0.5 : 1.0)
                            }

                            // Recurrence Pill
                            if task.isRecurring, let recurrenceDesc = task.recurrenceDescription {
                                HStack(spacing: 3) {
                                    Image(systemName: "repeat")
                                        .font(.caption2)
                                    Text(recurrenceDesc)
                                        .font(.caption2)
                                }
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.purple.opacity(0.15)))
                                .opacity(task.isCompleted ? 0.5 : 1.0)
                            }

                            // List Pill
                            if let list = task.taskList {
                                HStack(spacing: 3) {
                                    Image(systemName: list.iconName ?? "list.bullet")
                                        .font(.caption2)
                                    Text(list.name)
                                        .font(.caption2)
                                }
                                .foregroundStyle(list.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(list.color.opacity(0.15)))
                                .opacity(task.isCompleted ? 0.5 : 1.0)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, task.priority > 0 ? 8 : 12)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var hasMetadata: Bool {
        !task.isCompleted || task.isRecurring || task.priority > 0 || task.taskList != nil || task.formattedScheduledTime != nil
    }

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

// MARK: - Focus Timer Full View (Pomodoro)
struct FocusTimerFullView: View {
    @ObservedObject var viewModel: FocusTimerViewModel
    let task: TaskEntity
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background gradient
                LinearGradient(
                    colors: [
                        timerColor.opacity(viewModel.timerState == .running ? 0.08 : 0.05),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: viewModel.timerState)

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 24)

                        // Task title and session type
                        VStack(spacing: 16) {
                            Text(task.title)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 32)
                                .foregroundStyle(.primary)

                            // Session type badge
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                                    .font(.caption)
                                Text(viewModel.sessionType)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(timerColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(timerColor.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(timerColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: timerColor.opacity(0.2), radius: 8, y: 4)
                        }

                        // Progress Ring with enhanced visuals
                        ZStack {
                            // Pulsing outer glow (only when running)
                            if viewModel.timerState == .running {
                                Circle()
                                    .stroke(timerColor.opacity(0.2), lineWidth: 24)
                                    .blur(radius: 12)
                                    .scaleEffect(1.05)
                                    .opacity(viewModel.timerState == .running ? 1 : 0)
                                    .animation(
                                        .easeInOut(duration: 2)
                                            .repeatForever(autoreverses: true),
                                        value: viewModel.timerState
                                    )
                            }

                            // Background ring
                            Circle()
                                .stroke(
                                    Color(.systemGray5),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )

                            // Progress ring
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(
                                    LinearGradient(
                                        colors: [timerColor, timerColor.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .shadow(color: timerColor.opacity(0.4), radius: 10, x: 0, y: 6)
                                .animation(.linear(duration: 1), value: viewModel.progress)

                            // Inner content
                            VStack(spacing: 12) {
                                // Timer text
                                Text(viewModel.formattedTime)
                                    .font(.system(size: 76, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [timerColor, timerColor.opacity(0.75)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .scaleEffect(viewModel.timerState == .running ? 1.0 : 0.95)
                                    .animation(.spring(response: 0.3), value: viewModel.timerState)

                                // State indicator
                                if viewModel.timerState == .paused {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 8, height: 8)
                                        Text("Paused")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                        }
                        .frame(width: 320, height: 320)
                        .padding(.vertical, 16)

                        // Controls
                        HStack(spacing: 28) {
                            // Stop Button
                            if viewModel.timerState != .idle {
                                Button {
                                    viewModel.stopTimer()
                                    onDismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(.systemGray6))
                                                .frame(width: 64, height: 64)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                                )
                                            Image(systemName: "stop.fill")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundStyle(.red)
                                        }
                                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                        Text("Stop")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }

                            // Play/Pause Button
                            Button {
                                switch viewModel.timerState {
                                case .idle, .completed:
                                    viewModel.startTimer(for: task)
                                case .running:
                                    viewModel.pauseTimer()
                                case .paused:
                                    viewModel.resumeTimer()
                                }
                            } label: {
                                VStack(spacing: 12) {
                                    ZStack {
                                        // Animated glow
                                        Circle()
                                            .fill(timerColor)
                                            .frame(width: 96, height: 96)
                                            .blur(radius: 24)
                                            .opacity(viewModel.timerState == .running ? 0.7 : 0.5)
                                            .scaleEffect(viewModel.timerState == .running ? 1.1 : 1.0)
                                            .animation(
                                                viewModel.timerState == .running ?
                                                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                                                    .easeInOut(duration: 0.3),
                                                value: viewModel.timerState
                                            )

                                        // Main button
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [timerColor, timerColor.opacity(0.85)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 96, height: 96)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.3), .clear],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                            )
                                            .shadow(color: timerColor.opacity(0.4), radius: 16, y: 8)

                                        // Icon
                                        Image(systemName: playPauseIcon)
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundStyle(.white)
                                            .scaleEffect(viewModel.timerState == .running ? 1.0 : 1.1)
                                            .animation(.spring(response: 0.3), value: viewModel.timerState)
                                    }
                                    Text(playPauseLabel)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(timerColor)
                                }
                            }
                            .buttonStyle(.plain)

                            // Skip Break Button
                            if viewModel.isBreak {
                                Button {
                                    viewModel.resetTimer()
                                    onDismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(.systemGray6))
                                                .frame(width: 64, height: 64)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                                )
                                            Image(systemName: "forward.fill")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundStyle(.orange)
                                        }
                                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                        Text("Skip")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.vertical, 8)

                        // Stats
                        if !viewModel.isBreak {
                            VStack(spacing: 20) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 4)
                                    .padding(.top, 8)

                                HStack(spacing: 24) {
                                    // Total Focus Time
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)
                                                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))
                                            Image(systemName: "clock.fill")
                                                .font(.title2)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.blue, .blue.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        VStack(spacing: 4) {
                                            Text(task.formattedFocusTime)
                                                .font(.title2.weight(.bold))
                                                .monospacedDigit()
                                            Text("Total Focus")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.secondarySystemBackground))
                                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                    )

                                    // Sessions Completed
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)
                                                .overlay(Circle().stroke(Color.green.opacity(0.2), lineWidth: 1))
                                            Image(systemName: "target")
                                                .font(.title2)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.green, .green.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        VStack(spacing: 4) {
                                            if let sessions = task.focusSessions as? Set<FocusSessionEntity> {
                                                Text("\(sessions.filter { $0.completed }.count)")
                                                    .font(.title2.weight(.bold))
                                            } else {
                                                Text("0")
                                                    .font(.title2.weight(.bold))
                                            }
                                            Text("Sessions")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.secondarySystemBackground))
                                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 12)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var timerColor: Color {
        if viewModel.isBreak {
            return .green
        }
        switch viewModel.timerState {
        case .idle: return .blue
        case .running: return .orange
        case .paused: return .yellow
        case .completed: return .green
        }
    }

    private var playPauseIcon: String {
        switch viewModel.timerState {
        case .idle, .completed:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.fill"
        }
    }

    private var playPauseLabel: String {
        switch viewModel.timerState {
        case .idle, .completed:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        }
    }
}

// MARK: - Preview
#Preview {
    TodayView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
