//
//  CalendarEventView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Interactive calendar event view with tap, resize, and selection capabilities
struct CalendarEventView: View {

    // MARK: - Properties
    let task: TaskEntity
    let layout: TaskLayout
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onResizeStart: (ResizeEdge, CGPoint) -> Void
    let onResizeChanged: (ResizeEdge, CGPoint) -> Void
    let onResizeEnded: () -> Void

    // MARK: - State
    @State private var isPressed = false
    @State private var showActions = false
    @State private var activeResizeEdge: ResizeEdge?

    // MARK: - Types
    enum ResizeEdge {
        case top, bottom
    }

    // MARK: - Constants
    private enum Layout {
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 2
        static let padding: CGFloat = 8
        static let resizeHandleHeight: CGFloat = 12
        static let resizeHandleWidth: CGFloat = 40
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .stroke(
                            isSelected ? Color.blue : (task.isCompleted ? Color.green : Color.blue),
                            lineWidth: isSelected ? 3 : Layout.borderWidth
                        )
                )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(task.isCompleted ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)

                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }

                if let time = task.formattedScheduledTime {
                    Text(time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Show duration if event is tall enough
                if layout.frame.height > 60 {
                    Spacer(minLength: 0)

                    if let duration = formatDuration() {
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Layout.padding)

            // Resize handles (only when selected)
            if isSelected {
                VStack(spacing: 0) {
                    // Top resize handle
                    topResizeHandle

                    Spacer()

                    // Bottom resize handle
                    bottomResizeHandle
                }
            }
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(color: isSelected ? .black.opacity(0.15) : .clear, radius: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .onTapGesture {
            HapticManager.shared.lightImpact()
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            pressing: { pressing in
                isPressed = pressing
                if pressing {
                    HapticManager.shared.mediumImpact()
                }
            },
            perform: {
                showActions = true
            }
        )
        .confirmationDialog("Event Actions", isPresented: $showActions) {
            Button("Delete", role: .destructive) {
                HapticManager.shared.mediumImpact()
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(isSelected ? "Double tap to deselect. Swipe up or down to resize." : "Double tap to select and edit")
    }

    // MARK: - Resize Handles
    private var topResizeHandle: some View {
        ZStack {
            // Invisible tap area
            Rectangle()
                .fill(Color.clear)
                .frame(height: Layout.resizeHandleHeight)
                .contentShape(Rectangle())

            // Visual indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: Layout.resizeHandleWidth, height: 4)
                .padding(.top, 2)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if activeResizeEdge == nil {
                        activeResizeEdge = .top
                        onResizeStart(.top, value.location)
                        HapticManager.shared.selectionChanged()
                    }
                    onResizeChanged(.top, value.location)
                }
                .onEnded { _ in
                    activeResizeEdge = nil
                    onResizeEnded()
                    HapticManager.shared.lightImpact()
                }
        )
        .accessibilityLabel("Resize handle top")
        .accessibilityHint("Drag to adjust start time")
    }

    private var bottomResizeHandle: some View {
        ZStack {
            // Visual indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: Layout.resizeHandleWidth, height: 4)
                .padding(.bottom, 2)

            // Invisible tap area
            Rectangle()
                .fill(Color.clear)
                .frame(height: Layout.resizeHandleHeight)
                .contentShape(Rectangle())
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if activeResizeEdge == nil {
                        activeResizeEdge = .bottom
                        onResizeStart(.bottom, value.location)
                        HapticManager.shared.selectionChanged()
                    }
                    onResizeChanged(.bottom, value.location)
                }
                .onEnded { _ in
                    activeResizeEdge = nil
                    onResizeEnded()
                    HapticManager.shared.lightImpact()
                }
        )
        .accessibilityLabel("Resize handle bottom")
        .accessibilityHint("Drag to adjust end time")
    }

    // MARK: - Helper Methods
    private func formatDuration() -> String? {
        guard let startTime = task.scheduledTime else { return nil }
        let endTime = task.scheduledEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startTime)!
        let durationInSeconds = endTime.timeIntervalSince(startTime)
        let durationInMinutes = Int(durationInSeconds / 60)

        if durationInMinutes < 60 {
            return "\(durationInMinutes) min"
        } else {
            let hours = durationInMinutes / 60
            let minutes = durationInMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    private var accessibilityDescription: String {
        guard let startTime = task.scheduledTime else {
            return task.title
        }

        let startString = AppDateFormatters.timeFormatter.string(from: startTime)
        let endTime = task.scheduledEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startTime)!
        let endString = AppDateFormatters.timeFormatter.string(from: endTime)

        let completionStatus = task.isCompleted ? "Completed" : "Incomplete"
        return "\(task.title), \(completionStatus), from \(startString) to \(endString)"
    }
}

// MARK: - Preview
#Preview("Single Event") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Team Meeting"
    task.scheduledTime = Date()
    task.scheduledEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
    task.isCompleted = false

    let layout = TaskLayout(
        task: task,
        frame: CGRect(x: 0, y: 100, width: 300, height: 80),
        column: 0,
        totalColumns: 1
    )

    return ZStack {
        Color.gray.opacity(0.1)

        CalendarEventView(
            task: task,
            layout: layout,
            isSelected: false,
            onTap: {
                print("Tapped")
            },
            onDelete: {
                print("Delete")
            },
            onResizeStart: { edge, location in
                print("Resize start: \(edge)")
            },
            onResizeChanged: { edge, location in
                print("Resize changed: \(edge)")
            },
            onResizeEnded: {
                print("Resize ended")
            }
        )
    }
}

#Preview("Selected Event") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Code Review"
    task.scheduledTime = Date()
    task.scheduledEndTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
    task.isCompleted = false

    let layout = TaskLayout(
        task: task,
        frame: CGRect(x: 0, y: 100, width: 300, height: 120),
        column: 0,
        totalColumns: 1
    )

    return ZStack {
        Color.gray.opacity(0.1)

        CalendarEventView(
            task: task,
            layout: layout,
            isSelected: true,
            onTap: {
                print("Tapped")
            },
            onDelete: {
                print("Delete")
            },
            onResizeStart: { edge, location in
                print("Resize start: \(edge)")
            },
            onResizeChanged: { edge, location in
                print("Resize changed: \(edge)")
            },
            onResizeEnded: {
                print("Resize ended")
            }
        )
    }
}
