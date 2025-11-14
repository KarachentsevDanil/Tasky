//
//  CompactTaskCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Compact card showing task details in calendar view
struct CompactTaskCard: View {
    let task: TaskEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)

            if let list = task.taskList {
                Label(list.name, systemImage: list.iconName ?? "list.bullet")
                    .font(.caption2)
                    .foregroundStyle(list.color)
            }
        }
        .padding(8)
        .frame(width: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

#Preview {
    CompactTaskCard(
        task: {
            let controller = PersistenceController.preview
            let task = TaskEntity(context: controller.container.viewContext)
            task.title = "Sample Task"
            return task
        }()
    )
}
