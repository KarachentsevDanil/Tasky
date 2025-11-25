# Tasky AI Feature Expansion - Comprehensive Specification

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Design Decisions](#design-decisions)
3. [Local LLM Considerations](#local-llm-considerations)
4. [Feature Priority Matrix](#feature-priority-matrix)
5. [Phase 1: All Core Tools](#phase-1-all-core-tools)
6. [Phase 2: Batch Operations](#phase-2-batch-operations)
7. [System Prompt Architecture](#system-prompt-architecture)
8. [Shared Infrastructure](#shared-infrastructure)
9. [Undo System Architecture](#undo-system-architecture)
10. [UI/UX Patterns](#uiux-patterns)
11. [Testing Strategy](#testing-strategy)
12. [Implementation Checklist](#implementation-checklist)

---

## Executive Summary

This document outlines 8 new AI tools for Tasky, designed specifically for Apple's on-device FoundationModels framework. Each tool is optimized for local LLM constraints with clear, focused functionality.

### Current State
| Capability | Status |
|------------|--------|
| Create tasks | ✅ Implemented (CreateTasksTool) |
| Query tasks | ✅ Implemented (QueryTasksTool) |
| Update tasks | ❌ Not available |
| Complete tasks | ❌ Not available |
| Delete tasks | ❌ Not available |
| Reschedule tasks | ❌ Not available |
| Manage lists | ❌ Not available |
| View analytics | ❌ Not available |
| Focus sessions | ❌ Not available |
| Batch operations | ❌ Not available |

### Proposed Tools (All in Phase 1)
| # | Tool | RICE Score | Phase | Effort |
|---|------|------------|-------|--------|
| 1 | CompleteTaskTool | 38.0 | 1 | 0.5 |
| 2 | UpdateTaskTool | 28.8 | 1 | 0.5 |
| 3 | RescheduleTaskTool | 20.4 | 1 | 0.5 |
| 4 | DeleteTaskTool | 18.9 | 1 | 0.5 |
| 5 | ManageListTool | 6.0 | 1 | 1.0 |
| 6 | TaskAnalyticsTool (Rich) | 4.5 | 1 | 1.5 |
| 7 | FocusSessionTool | 1.87 | 1 | 1.5 |
| 8 | BatchOperationsTool | 1.35 | 2 | 2.0 |

---

## Design Decisions

### 1. Scope: All Tools in Phase 1
**Decision:** Include ALL tools (except batch operations) in Phase 1 for comprehensive AI capabilities from launch.

**Rationale:**
- Users expect full AI assistant functionality
- Voice-first experience requires complete feature parity with UI
- Focus sessions are highly valuable for voice ("start 25-minute focus on report")
- Analytics enable "how am I doing?" queries immediately

### 2. Undo Strategy: 5-Second Window (Option A)
**Decision:** Use the same 5-second undo window pattern as the existing UI for consistency.

**Implementation:**
- All destructive operations (complete, delete, update, reschedule) post notifications
- UI shows toast with "Undo" button that expires in 5 seconds
- Matches existing `toggleTaskCompletionWithUndo()` and `deleteTaskWithUndo()` patterns
- No pre-confirmation required (faster for voice)

**Why not Option B (confirmation)?**
- Slower user experience, especially for voice
- Inconsistent with existing UI patterns
- Undo is safer than "are you sure?" dialogs

### 3. Focus Sessions: Full Implementation
**Decision:** Include FocusSessionTool with complete implementation using existing FocusTimerViewModel infrastructure.

**Capabilities:**
- Start focus session on any task
- Stop current session
- Check session status
- Support common durations (15, 25, 45, 60 minutes)

### 4. Analytics Depth: Rich Insights
**Decision:** Implement comprehensive analytics with streaks, productivity patterns, and time-of-day insights.

**Analytics Types:**
- `daily_summary` - Today's progress with motivational feedback
- `weekly_summary` - Week trends, busiest day, daily average
- `monthly_summary` - Monthly trends, best week, goal tracking
- `completion_rate` - Overall and by-list completion percentages
- `overdue_count` - Overdue tasks with age and urgency
- `list_breakdown` - Tasks per list with completion rates
- `productivity_streak` - Consecutive days with completions
- `best_time` - Most productive time of day analysis
- `focus_stats` - Focus session statistics and total focus time
- `weekly_comparison` - This week vs last week comparison

---

## Local LLM Considerations

### Apple Intelligence Constraints
```
Context Window: Limited (exact size undisclosed)
Reasoning: Pattern-matching, not deep inference
Latency: Fast (on-device), but resource-constrained
Reliability: May struggle with ambiguous requests
Tool Calling: Supports @Generable structs with @Guide annotations
```

### Prompt Engineering Principles for Local LLMs

#### 1. Explicit Intent Mapping
```
❌ BAD (ambiguous):
"Handle task modifications"

✅ GOOD (explicit):
"When user says 'done', 'finished', 'completed', or 'mark as done',
use complete_task tool with completed=true"
```

#### 2. Constrained Parameters
```swift
// ❌ BAD: Open-ended string
@Guide(description: "The action to perform")
let action: String

// ✅ GOOD: Explicit options listed
@Guide(description: "Action: create, rename, or delete")
let action: String
```

#### 3. Sensible Defaults
```swift
// ❌ BAD: Required parameter without default behavior
@Guide(description: "Duration in minutes")
let duration: Int

// ✅ GOOD: Optional with default documented
@Guide(description: "Duration in minutes (default 25)")
let duration: Int?
```

#### 4. Single Responsibility
```
❌ BAD: One tool that creates, updates, and deletes
✅ GOOD: Separate tools for each operation
```

#### 5. Format Specification
```
❌ BAD: "Enter a date"
✅ GOOD: "Date in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ (e.g., 2025-11-25T14:30:00Z)"
```

---

## Feature Priority Matrix

### RICE Scoring Methodology
```
RICE = (Reach × Impact × Confidence) / Effort

Reach (1-10): How many users will use this weekly?
Impact (0.25-3): How much does it improve experience?
Confidence (50-100%): How sure are we about estimates?
Effort (0.5-6): Person-weeks to implement
```

### Detailed Scoring

| Tool | Reach | Impact | Confidence | Effort | Score |
|------|-------|--------|------------|--------|-------|
| CompleteTaskTool | 10 | 2.0 | 95% | 0.5 | **38.0** |
| UpdateTaskTool | 8 | 2.0 | 90% | 0.5 | **28.8** |
| RescheduleTaskTool | 8 | 1.5 | 85% | 0.5 | **20.4** |
| DeleteTaskTool | 7 | 1.5 | 90% | 0.5 | **18.9** |
| ManageListTool | 5 | 1.5 | 80% | 1.0 | **6.0** |
| TaskAnalyticsTool | 6 | 1.5 | 75% | 1.5 | **4.5** |
| FocusSessionTool | 4 | 1.5 | 70% | 1.5 | **2.8** |
| BatchOperationsTool | 3 | 1.5 | 60% | 2.0 | **1.35** |

---

## Phase 1: All Core Tools

### Tool 1: CompleteTaskTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `complete_task` |
| Purpose | Mark tasks as complete or incomplete |
| RICE Score | 38.0 (Highest Priority) |
| Complexity | Low |
| Undo | 5-second window via notification |

#### User Stories
- "As a user, I want to say 'done with groceries' and have that task marked complete"
- "As a user, I want to reopen a task I accidentally completed"
- "As a user, I want voice-free task completion while cooking/driving"

#### Natural Language Triggers
```
Complete:
- "done with [task]"
- "finished [task]"
- "completed [task]"
- "mark [task] as done"
- "check off [task]"
- "[task] is done"

Reopen:
- "reopen [task]"
- "unfinish [task]"
- "mark [task] as not done"
- "uncomplete [task]"
```

#### Full Implementation

```swift
//
//  CompleteTaskTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for marking tasks as complete or incomplete via LLM
struct CompleteTaskTool: Tool {
    let name = "complete_task"

    let description = """
    Mark a task as complete or incomplete. Use this when the user says they're done with a task, \
    finished something, or wants to check off a task. Also use when user wants to reopen/uncomplete a task.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Task title to find (exact or partial match). Example: 'groceries' or 'buy groceries'")
        let taskTitle: String

        @Guide(description: "Set to true to mark complete, false to mark incomplete/reopen")
        let completed: Bool
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeCompletion(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeCompletion(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(arguments.taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "❌ Couldn't find a task matching '\(arguments.taskTitle)'. Try using more of the task title."
            } else {
                return "❌ Couldn't find '\(arguments.taskTitle)'. Did you mean one of these?\n\(suggestion)"
            }
        }

        // Check if already in desired state
        if task.isCompleted == arguments.completed {
            let state = arguments.completed ? "already complete" : "already incomplete"
            return "ℹ️ '\(task.title ?? "Task")' is \(state)."
        }

        // Store previous state for undo
        let previousState = task.isCompleted
        let taskId = task.id
        let taskTitle = task.title ?? "Task"

        // Toggle completion
        do {
            try dataService.toggleTaskCompletion(task)

            let action = arguments.completed ? "completed" : "reopened"
            let emoji = arguments.completed ? "✅" : "🔄"

            // Post notification for UI feedback with undo support
            NotificationCenter.default.post(
                name: .aiTaskCompleted,
                object: nil,
                userInfo: [
                    "taskId": taskId as Any,
                    "taskTitle": taskTitle,
                    "completed": arguments.completed,
                    "previousState": previousState,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            return "\(emoji) '\(taskTitle)' \(action)!"

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to update task: \(error.localizedDescription)"
        }
    }
}
```

#### System Prompt Section
```
TASK COMPLETION:
- When user says "done", "finished", "completed", or "check off" → complete_task with completed=true
- When user says "reopen", "uncomplete", "undo complete" → complete_task with completed=false
- Match tasks by title (partial matching supported)
- Examples:
  - "done with groceries" → complete_task(taskTitle: "groceries", completed: true)
  - "reopen the meeting task" → complete_task(taskTitle: "meeting", completed: false)
```

---

### Tool 2: UpdateTaskTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `update_task` |
| Purpose | Modify existing task properties |
| RICE Score | 28.8 |
| Complexity | Medium |
| Undo | 5-second window via notification |

#### Natural Language Triggers
```
Title changes:
- "rename [task] to [new name]"
- "change [task] title to [new name]"

Priority changes:
- "make [task] high/medium/low priority"
- "set priority of [task] to high"
- "[task] is urgent/important"

Notes:
- "add note to [task]: [note]"
- "update notes for [task]"

List changes:
- "move [task] to [list]"
- "put [task] in [list]"
```

#### Full Implementation

```swift
//
//  UpdateTaskTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for updating existing task properties via LLM
struct UpdateTaskTool: Tool {
    let name = "update_task"

    let description = """
    Update properties of an existing task. Use this when the user wants to change a task's title, \
    notes, priority, or list assignment. Only include fields that need to change.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Current task title to find (exact or partial match)")
        let taskTitle: String

        @Guide(description: "New title for the task (optional, only if renaming)")
        let newTitle: String?

        @Guide(description: "New notes/description (optional)")
        let newNotes: String?

        @Guide(description: "New priority: 0 (none), 1 (low), 2 (medium), 3 (high)")
        let newPriority: Int?

        @Guide(description: "New list name to move task to (optional)")
        let newListName: String?

        @Guide(description: "New due date in ISO 8601 format YYYY-MM-DDTHH:MM:SSZ (optional)")
        let newDueDate: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeUpdate(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeUpdate(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(arguments.taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "❌ Couldn't find a task matching '\(arguments.taskTitle)'."
            } else {
                return "❌ Couldn't find '\(arguments.taskTitle)'. Did you mean:\n\(suggestion)"
            }
        }

        // Store previous state for undo
        let previousState = TaskPreviousState(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            priority: task.priority,
            listId: task.taskList?.id
        )

        // Track what changed for response
        var changes: [String] = []
        let originalTitle = task.title ?? "Task"

        // Find list if specified
        var targetList: TaskListEntity? = task.taskList
        if let listName = arguments.newListName {
            if let matchedList = AIToolHelpers.findList(listName, dataService: dataService) {
                targetList = matchedList
                changes.append("moved to '\(matchedList.name)'")
            } else {
                return "❌ List '\(listName)' not found. Available lists: \(AIToolHelpers.getAvailableListNames(dataService: dataService))"
            }
        }

        // Parse due date if provided
        var newDueDate: Date? = task.dueDate
        if let dueDateString = arguments.newDueDate {
            if let parsed = AIToolHelpers.parseISO8601Date(dueDateString) {
                newDueDate = parsed
                changes.append("due date set to \(AIToolHelpers.formatRelativeDate(parsed))")
            } else {
                return "❌ Invalid date format. Use ISO 8601: YYYY-MM-DDTHH:MM:SSZ"
            }
        }

        // Validate priority
        var newPriority = task.priority
        if let priority = arguments.newPriority {
            let clampedPriority = Int16(min(max(priority, 0), 3))
            newPriority = clampedPriority
            let priorityNames = ["none", "low", "medium", "high"]
            changes.append("priority set to \(priorityNames[Int(clampedPriority)])")
        }

        // Track title change
        var finalTitle = task.title
        if let newTitle = arguments.newTitle, !newTitle.isEmpty {
            finalTitle = newTitle
            changes.append("renamed to '\(newTitle)'")
        }

        // Track notes change
        var finalNotes = task.notes
        if let newNotes = arguments.newNotes {
            finalNotes = newNotes
            changes.append("notes updated")
        }

        // Check if anything changed
        if changes.isEmpty {
            return "ℹ️ No changes specified for '\(originalTitle)'."
        }

        // Perform update
        do {
            try dataService.updateTask(
                task,
                title: finalTitle,
                notes: finalNotes,
                dueDate: newDueDate,
                scheduledTime: task.scheduledTime,
                scheduledEndTime: task.scheduledEndTime,
                priority: newPriority,
                priorityOrder: task.priorityOrder,
                list: targetList
            )

            // Post notification for UI feedback with undo support
            NotificationCenter.default.post(
                name: .aiTaskUpdated,
                object: nil,
                userInfo: [
                    "taskId": task.id as Any,
                    "taskTitle": originalTitle,
                    "changes": changes,
                    "previousState": previousState,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            let changeList = changes.joined(separator: ", ")
            return "✅ Updated '\(originalTitle)': \(changeList)"

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to update task: \(error.localizedDescription)"
        }
    }
}

/// Stores previous task state for undo functionality
struct TaskPreviousState {
    let title: String?
    let notes: String?
    let dueDate: Date?
    let priority: Int16
    let listId: UUID?
}
```

#### System Prompt Section
```
TASK UPDATES:
- When user wants to change task properties → update_task
- Only include fields that need to change
- Priority: 0=none, 1=low, 2=medium, 3=high
- Dates must be ISO 8601 format
- Examples:
  - "make groceries high priority" → update_task(taskTitle: "groceries", newPriority: 3)
  - "rename meeting to team sync" → update_task(taskTitle: "meeting", newTitle: "team sync")
  - "move groceries to Personal list" → update_task(taskTitle: "groceries", newListName: "Personal")
```

---

### Tool 3: RescheduleTaskTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `reschedule_task` |
| Purpose | Change task dates with natural language |
| RICE Score | 20.4 |
| Complexity | Low |
| Undo | 5-second window via notification |

#### Why Separate Tool?
Rescheduling is the most common task edit. A dedicated tool allows:
- Simpler LLM decision making (clear when to use)
- Natural shortcuts (today, tomorrow, next week)
- Better prompt engineering for local LLM

#### Natural Language Triggers
```
- "move [task] to tomorrow"
- "postpone [task]"
- "reschedule [task] to next week"
- "do [task] today instead"
- "[task] at 3pm"
- "push [task] to Friday"
```

#### Full Implementation

```swift
//
//  RescheduleTaskTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for rescheduling tasks with natural date expressions
struct RescheduleTaskTool: Tool {
    let name = "reschedule_task"

    let description = """
    Reschedule a task to a different date or time. Use this when user wants to move, postpone, \
    or change when a task is due. Supports shortcuts like today, tomorrow, next_week.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Task title to reschedule (exact or partial match)")
        let taskTitle: String

        @Guide(description: "When to reschedule: today, tomorrow, next_week, next_month, monday, tuesday, wednesday, thursday, friday, saturday, sunday, or specific_date")
        let when: String

        @Guide(description: "Specific date in ISO 8601 format (only if when=specific_date)")
        let specificDate: String?

        @Guide(description: "Time in HH:MM format like 14:30 (optional, for scheduling specific time)")
        let time: String?

        @Guide(description: "Duration in minutes for time-blocked scheduling (optional)")
        let durationMinutes: Int?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeReschedule(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeReschedule(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            return "❌ Couldn't find a task matching '\(arguments.taskTitle)'."
        }

        // Store previous state for undo
        let previousDueDate = task.dueDate
        let previousScheduledTime = task.scheduledTime
        let previousScheduledEndTime = task.scheduledEndTime
        let taskTitle = task.title ?? "Task"

        // Calculate new date
        guard let newDate = AIToolHelpers.calculateNewDate(arguments.when, specificDate: arguments.specificDate) else {
            return "❌ Invalid date. Use: today, tomorrow, next_week, next_month, weekday names, or specific_date with ISO 8601 format."
        }

        // Parse optional time
        var scheduledTime: Date? = nil
        var scheduledEndTime: Date? = nil

        if let timeString = arguments.time {
            if let time = AIToolHelpers.parseTime(timeString, onDate: newDate) {
                scheduledTime = time

                // Calculate end time if duration provided
                if let duration = arguments.durationMinutes, duration > 0 {
                    scheduledEndTime = Calendar.current.date(byAdding: .minute, value: duration, to: time)
                }
            }
        }

        // Perform update
        do {
            try dataService.updateTask(
                task,
                title: task.title,
                notes: task.notes,
                dueDate: newDate,
                scheduledTime: scheduledTime,
                scheduledEndTime: scheduledEndTime,
                priority: task.priority,
                priorityOrder: task.priorityOrder,
                list: task.taskList
            )

            // Build response
            var response = "📅 '\(taskTitle)' rescheduled to \(AIToolHelpers.formatRelativeDate(newDate))"

            if let time = scheduledTime {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                response += " at \(timeFormatter.string(from: time))"

                if let endTime = scheduledEndTime {
                    response += " - \(timeFormatter.string(from: endTime))"
                }
            }

            // Post notification with undo support
            NotificationCenter.default.post(
                name: .aiTaskRescheduled,
                object: nil,
                userInfo: [
                    "taskId": task.id as Any,
                    "taskTitle": taskTitle,
                    "newDate": newDate,
                    "previousDueDate": previousDueDate as Any,
                    "previousScheduledTime": previousScheduledTime as Any,
                    "previousScheduledEndTime": previousScheduledEndTime as Any,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            return response

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to reschedule: \(error.localizedDescription)"
        }
    }
}
```

#### System Prompt Section
```
RESCHEDULING:
- When user wants to move/postpone/reschedule a task → reschedule_task
- Shortcuts: today, tomorrow, next_week, next_month, monday-sunday
- For specific dates: when=specific_date with specificDate in ISO 8601
- Time is optional (HH:MM format like "14:30")
- Examples:
  - "move groceries to tomorrow" → reschedule_task(taskTitle: "groceries", when: "tomorrow")
  - "meeting at 3pm today" → reschedule_task(taskTitle: "meeting", when: "today", time: "15:00")
  - "do report on Friday" → reschedule_task(taskTitle: "report", when: "friday")
```

---

### Tool 4: DeleteTaskTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `delete_task` |
| Purpose | Remove tasks |
| RICE Score | 18.9 |
| Complexity | Low |
| Undo | 5-second window via soft delete |

#### Safety Considerations
- Uses soft delete with 5-second undo window
- No confirmation required (faster UX)
- Task can be restored via undo

#### Full Implementation

```swift
//
//  DeleteTaskTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for deleting tasks via LLM with undo support
struct DeleteTaskTool: Tool {
    let name = "delete_task"

    let description = """
    Delete a task. Use this when user explicitly wants to remove, delete, or cancel a task. \
    Use complete_task instead if user just finished the task.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Task title to delete (exact or partial match)")
        let taskTitle: String
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeDelete(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeDelete(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            return "❌ Couldn't find a task matching '\(arguments.taskTitle)'."
        }

        let taskTitle = task.title ?? "Task"
        let taskId = task.id

        // Store complete task info for undo restoration
        let deletedTaskInfo = DeletedTaskInfo(
            id: taskId,
            title: taskTitle,
            notes: task.notes,
            dueDate: task.dueDate,
            scheduledTime: task.scheduledTime,
            scheduledEndTime: task.scheduledEndTime,
            priority: Int(task.priority),
            listId: task.taskList?.id,
            listName: task.taskList?.name,
            isRecurring: task.isRecurring,
            recurrenceDays: task.recurrenceDays,
            estimatedDuration: Int(task.estimatedDuration)
        )

        // Perform deletion
        do {
            try dataService.deleteTask(task)

            // Post notification for undo UI (5-second window)
            NotificationCenter.default.post(
                name: .aiTaskDeleted,
                object: nil,
                userInfo: [
                    "deletedTaskInfo": deletedTaskInfo,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.lightImpact()

            return "🗑️ Deleted '\(taskTitle)'"

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to delete task: \(error.localizedDescription)"
        }
    }
}

/// Complete task info stored for undo restoration
struct DeletedTaskInfo {
    let id: UUID?
    let title: String
    let notes: String?
    let dueDate: Date?
    let scheduledTime: Date?
    let scheduledEndTime: Date?
    let priority: Int
    let listId: UUID?
    let listName: String?
    let isRecurring: Bool
    let recurrenceDays: String?
    let estimatedDuration: Int
}
```

#### System Prompt Section
```
DELETE TASK:
- When user says "delete", "remove", "cancel task" → delete_task
- Do NOT use for completed tasks (use complete_task instead)
- Examples:
  - "delete the groceries task" → delete_task(taskTitle: "groceries")
  - "remove meeting from my list" → delete_task(taskTitle: "meeting")
```

---

### Tool 5: ManageListTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `manage_list` |
| Purpose | Create, rename, or delete task lists |
| RICE Score | 6.0 |
| Complexity | Medium |
| Undo | 5-second window for delete |

#### Full Implementation

```swift
//
//  ManageListTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for creating, renaming, and deleting task lists
struct ManageListTool: Tool {
    let name = "manage_list"

    let description = """
    Create, rename, or delete task lists/projects. Use this when user wants to organize tasks into lists.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Action to perform: create, rename, or delete")
        let action: String

        @Guide(description: "List name (for create: new name, for rename/delete: existing name)")
        let listName: String

        @Guide(description: "New name (only required for rename action)")
        let newName: String?

        @Guide(description: "Color: red, orange, yellow, green, blue, purple, pink, gray (optional for create)")
        let color: String?

        @Guide(description: "Icon: list, folder, briefcase, house, cart, heart, star, flag, book, gift (optional for create)")
        let icon: String?
    }

    // Color mapping
    private let colorMap: [String: String] = [
        "red": "#FF3B30",
        "orange": "#FF9500",
        "yellow": "#FFCC00",
        "green": "#34C759",
        "blue": "#007AFF",
        "purple": "#AF52DE",
        "pink": "#FF2D55",
        "gray": "#8E8E93"
    ]

    // Icon mapping
    private let validIcons = ["list.bullet", "folder", "briefcase", "house", "cart",
                               "heart", "star", "flag", "book", "graduationcap", "gift", "cup.and.saucer"]

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeAction(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAction(arguments: Arguments) async -> String {
        switch arguments.action.lowercased() {
        case "create":
            return await createList(arguments)
        case "rename":
            return await renameList(arguments)
        case "delete":
            return await deleteList(arguments)
        default:
            return "❌ Unknown action '\(arguments.action)'. Use: create, rename, or delete."
        }
    }

    @MainActor
    private func createList(_ arguments: Arguments) async -> String {
        let name = arguments.listName.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            return "❌ List name cannot be empty."
        }

        // Check if list already exists
        if let _ = AIToolHelpers.findList(name, dataService: dataService) {
            return "❌ A list named '\(name)' already exists."
        }

        // Get color hex
        let colorHex = arguments.color.flatMap { colorMap[$0.lowercased()] } ?? colorMap["blue"]!

        // Get icon name
        var iconName = "list.bullet"
        if let icon = arguments.icon?.lowercased() {
            if validIcons.contains(icon) {
                iconName = icon
            } else if validIcons.contains("\(icon).fill") {
                iconName = "\(icon).fill"
            }
        }

        do {
            let _ = try dataService.createTaskList(name: name, colorHex: colorHex, iconName: iconName)

            NotificationCenter.default.post(
                name: .aiListCreated,
                object: nil,
                userInfo: ["listName": name]
            )

            HapticManager.shared.success()

            return "📁 Created list '\(name)'"

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to create list: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func renameList(_ arguments: Arguments) async -> String {
        guard let newName = arguments.newName, !newName.isEmpty else {
            return "❌ Please specify the new name for the list."
        }

        guard let list = AIToolHelpers.findList(arguments.listName, dataService: dataService) else {
            return "❌ Couldn't find list '\(arguments.listName)'."
        }

        let oldName = list.name

        do {
            try dataService.updateTaskList(list, name: newName, colorHex: list.colorHex, iconName: list.iconName)

            NotificationCenter.default.post(
                name: .aiListUpdated,
                object: nil,
                userInfo: [
                    "listId": list.id as Any,
                    "oldName": oldName,
                    "newName": newName,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            return "✏️ Renamed '\(oldName)' to '\(newName)'"

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to rename list: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteList(_ arguments: Arguments) async -> String {
        guard let list = AIToolHelpers.findList(arguments.listName, dataService: dataService) else {
            return "❌ Couldn't find list '\(arguments.listName)'."
        }

        let listName = list.name
        let listId = list.id
        let taskCount = list.tasksArray.count
        let colorHex = list.colorHex
        let iconName = list.iconName

        do {
            try dataService.deleteTaskList(list)

            // Store info for potential undo
            NotificationCenter.default.post(
                name: .aiListDeleted,
                object: nil,
                userInfo: [
                    "listId": listId as Any,
                    "listName": listName,
                    "colorHex": colorHex as Any,
                    "iconName": iconName as Any,
                    "taskCount": taskCount,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.lightImpact()

            var response = "🗑️ Deleted list '\(listName)'"
            if taskCount > 0 {
                response += " (\(taskCount) tasks moved to Inbox)"
            }

            return response

        } catch {
            HapticManager.shared.error()
            return "❌ Failed to delete list: \(error.localizedDescription)"
        }
    }
}
```

#### System Prompt Section
```
LIST MANAGEMENT:
- When user wants to create/rename/delete lists → manage_list
- Colors: red, orange, yellow, green, blue, purple, pink, gray
- Icons: list, folder, briefcase, house, cart, heart, star, flag, book, gift
- Examples:
  - "create a Work list" → manage_list(action: "create", listName: "Work")
  - "create Shopping list with red color" → manage_list(action: "create", listName: "Shopping", color: "red")
  - "rename Personal to Home" → manage_list(action: "rename", listName: "Personal", newName: "Home")
  - "delete Work list" → manage_list(action: "delete", listName: "Work")
```

---

### Tool 6: TaskAnalyticsTool (Rich Analytics)

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `task_analytics` |
| Purpose | Provide rich productivity insights and statistics |
| RICE Score | 4.5 |
| Complexity | Medium-High |
| Dependencies | DataService query methods |

#### Rich Analytics Types
| Type | Description |
|------|-------------|
| `daily_summary` | Today's progress with motivational feedback |
| `weekly_summary` | Week trends, busiest day, daily average |
| `monthly_summary` | Monthly trends, best week, goal tracking |
| `completion_rate` | Overall and by-list completion percentages |
| `overdue_count` | Overdue tasks with age and urgency |
| `list_breakdown` | Tasks per list with completion rates |
| `productivity_streak` | Consecutive days with completions |
| `best_time` | Most productive time of day analysis |
| `focus_stats` | Focus session statistics and total focus time |
| `weekly_comparison` | This week vs last week comparison |

#### Full Implementation

```swift
//
//  TaskAnalyticsTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for providing rich task analytics and productivity insights
struct TaskAnalyticsTool: Tool {
    let name = "task_analytics"

    let description = """
    Get productivity statistics and insights about tasks. Use when user asks about progress, \
    how many tasks, completion rates, streaks, best times, or wants a summary of their productivity.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Analytics type: daily_summary, weekly_summary, monthly_summary, completion_rate, overdue_count, list_breakdown, productivity_streak, best_time, focus_stats, weekly_comparison")
        let analyticsType: String

        @Guide(description: "Optional list name to filter by")
        let listName: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeAnalytics(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAnalytics(arguments: Arguments) async -> String {
        switch arguments.analyticsType.lowercased() {
        case "daily_summary":
            return await getDailySummary(listName: arguments.listName)
        case "weekly_summary":
            return await getWeeklySummary(listName: arguments.listName)
        case "monthly_summary":
            return await getMonthlySummary(listName: arguments.listName)
        case "completion_rate":
            return await getCompletionRate(listName: arguments.listName)
        case "overdue_count":
            return await getOverdueCount(listName: arguments.listName)
        case "list_breakdown":
            return await getListBreakdown()
        case "productivity_streak":
            return await getProductivityStreak()
        case "best_time":
            return await getBestProductiveTime()
        case "focus_stats":
            return await getFocusStats(listName: arguments.listName)
        case "weekly_comparison":
            return await getWeeklyComparison()
        default:
            return "❌ Unknown analytics type. Use: daily_summary, weekly_summary, monthly_summary, completion_rate, overdue_count, list_breakdown, productivity_streak, best_time, focus_stats, weekly_comparison"
        }
    }

    // MARK: - Daily Summary

    @MainActor
    private func getDailySummary(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedToday = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today && completedAt < tomorrow
        }.count

        let dueToday = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate >= today && dueDate < tomorrow
        }.count

        let overdue = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < today
        }.count

        let totalIncomplete = tasks.filter { !$0.isCompleted }.count

        // Calculate completion percentage for today
        let totalDueToday = dueToday + completedToday
        let todayRate = totalDueToday > 0 ? Int((Double(completedToday) / Double(totalDueToday)) * 100) : 0

        var summary = "📊 **Today's Summary**\n"
        summary += "• Completed: \(completedToday)"
        if totalDueToday > 0 {
            summary += " (\(todayRate)% of today's tasks)"
        }
        summary += "\n"
        summary += "• Still due today: \(dueToday)\n"
        summary += "• Overdue: \(overdue)\n"
        summary += "• Total remaining: \(totalIncomplete)"

        // Add motivational feedback
        if completedToday >= 5 {
            summary += "\n\n🔥 On fire! \(completedToday) tasks completed!"
        } else if completedToday > 0 && dueToday == 0 && overdue == 0 {
            summary += "\n\n🎉 All caught up! Great job!"
        } else if overdue > 3 {
            summary += "\n\n⚠️ You have \(overdue) overdue tasks. Consider tackling the oldest ones first."
        } else if dueToday > 5 {
            summary += "\n\n💪 Busy day ahead! Focus on high-priority items."
        }

        return summary
    }

    // MARK: - Weekly Summary

    @MainActor
    private func getWeeklySummary(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedThisWeek = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }

        let completedCount = completedThisWeek.count

        // Calculate busiest day
        var dayCount: [Int: Int] = [:]
        for task in completedThisWeek {
            if let completedAt = task.completedAt {
                let weekday = calendar.component(.weekday, from: completedAt)
                dayCount[weekday, default: 0] += 1
            }
        }

        let busiestDay = dayCount.max(by: { $0.value < $1.value })
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let busiestDayName = busiestDay.map { dayNames[$0.key] } ?? "None"

        // Daily trend
        var dailyTrend = "📉"
        let lastThreeDays = completedThisWeek.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= calendar.date(byAdding: .day, value: -3, to: today)!
        }.count
        let firstFourDays = completedCount - lastThreeDays
        if lastThreeDays > firstFourDays / 2 {
            dailyTrend = "📈 Trending up!"
        }

        var summary = "📈 **This Week's Summary**\n"
        summary += "• Tasks completed: \(completedCount)\n"
        summary += "• Most productive day: \(busiestDayName)"
        if let busiest = busiestDay {
            summary += " (\(busiest.value) tasks)"
        }
        summary += "\n"

        // Daily average
        let avgPerDay = Double(completedCount) / 7.0
        summary += "• Daily average: \(String(format: "%.1f", avgPerDay)) tasks\n"
        summary += "• Trend: \(dailyTrend)"

        // Add achievement badges
        if completedCount >= 25 {
            summary += "\n\n🏆 Superstar! 25+ tasks in a week!"
        } else if completedCount >= 15 {
            summary += "\n\n⭐ Excellent week! Keep it up!"
        }

        return summary
    }

    // MARK: - Monthly Summary

    @MainActor
    private func getMonthlySummary(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedThisMonth = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= monthAgo
        }

        let completedCount = completedThisMonth.count

        // Find best week
        var weekCounts: [Int: Int] = [:]
        for task in completedThisMonth {
            if let completedAt = task.completedAt {
                let weekOfYear = calendar.component(.weekOfYear, from: completedAt)
                weekCounts[weekOfYear, default: 0] += 1
            }
        }
        let bestWeek = weekCounts.max(by: { $0.value < $1.value })

        var summary = "📅 **Monthly Summary (Last 30 Days)**\n"
        summary += "• Total completed: \(completedCount)\n"
        summary += "• Weekly average: \(String(format: "%.1f", Double(completedCount) / 4.0)) tasks\n"
        summary += "• Daily average: \(String(format: "%.1f", Double(completedCount) / 30.0)) tasks\n"

        if let best = bestWeek {
            summary += "• Best week: \(best.value) tasks completed"
        }

        return summary
    }

    // MARK: - Completion Rate

    @MainActor
    private func getCompletionRate(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        var tasks = allTasks
        var listInfo = ""
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
            listInfo = " for '\(listName)'"
        }

        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count

        guard total > 0 else {
            return "📊 No tasks found\(listInfo). Create some tasks to see your completion rate!"
        }

        let rate = Double(completed) / Double(total) * 100

        var emoji = "📊"
        var message = ""
        if rate >= 90 {
            emoji = "🏆"
            message = "Outstanding!"
        } else if rate >= 75 {
            emoji = "🌟"
            message = "Excellent progress!"
        } else if rate >= 50 {
            emoji = "👍"
            message = "Good momentum!"
        } else if rate >= 25 {
            emoji = "📈"
            message = "Building up!"
        } else {
            emoji = "💪"
            message = "Room to grow!"
        }

        var response = "\(emoji) **Completion Rate\(listInfo)**\n"
        response += "• \(completed) of \(total) tasks completed\n"
        response += "• Rate: \(String(format: "%.0f", rate))%\n"
        response += "• \(message)"

        return response
    }

    // MARK: - Overdue Count

    @MainActor
    private func getOverdueCount(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let today = Calendar.current.startOfDay(for: Date())

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let overdue = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < today
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        if overdue.isEmpty {
            return "✅ No overdue tasks! You're on track. 🎯"
        }

        // Categorize by age
        let critical = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days >= 7
        }
        let warning = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days >= 3 && days < 7
        }
        let recent = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days < 3
        }

        var response = "⚠️ **\(overdue.count) Overdue Task(s)**\n\n"

        if !critical.isEmpty {
            response += "🔴 **Critical (7+ days):** \(critical.count)\n"
        }
        if !warning.isEmpty {
            response += "🟠 **Warning (3-6 days):** \(warning.count)\n"
        }
        if !recent.isEmpty {
            response += "🟡 **Recent (1-2 days):** \(recent.count)\n"
        }

        response += "\n**Top 5 to address:**\n"
        for (index, task) in overdue.prefix(5).enumerated() {
            let daysOverdue = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            let urgency = daysOverdue >= 7 ? "🔴" : (daysOverdue >= 3 ? "🟠" : "🟡")
            response += "\(index + 1). \(urgency) \(task.title ?? "Untitled") (\(daysOverdue)d)\n"
        }

        if overdue.count > 5 {
            response += "\n... and \(overdue.count - 5) more"
        }

        return response
    }

    // MARK: - List Breakdown

    @MainActor
    private func getListBreakdown() async -> String {
        guard let allTasks = try? dataService.fetchAllTasks(),
              let lists = try? dataService.fetchAllTaskLists() else {
            return "❌ Could not fetch data."
        }

        var response = "📂 **Tasks by List**\n\n"

        // Inbox count
        let inboxTasks = allTasks.filter { $0.taskList == nil }
        let inboxIncomplete = inboxTasks.filter { !$0.isCompleted }.count
        let inboxTotal = inboxTasks.count
        let inboxRate = inboxTotal > 0 ? Int(Double(inboxTotal - inboxIncomplete) / Double(inboxTotal) * 100) : 0
        response += "📥 **Inbox:** \(inboxIncomplete) active (\(inboxRate)% complete)\n"

        // Each list
        for list in lists {
            let listTasks = allTasks.filter { $0.taskList?.id == list.id }
            let incomplete = listTasks.filter { !$0.isCompleted }.count
            let total = listTasks.count
            let rate = total > 0 ? Int(Double(total - incomplete) / Double(total) * 100) : 0

            let emoji = rate >= 75 ? "✅" : (rate >= 50 ? "📁" : "📋")
            response += "\(emoji) **\(list.name):** \(incomplete) active (\(rate)% complete)\n"
        }

        let totalIncomplete = allTasks.filter { !$0.isCompleted }.count
        let totalComplete = allTasks.filter { $0.isCompleted }.count
        response += "\n📊 **Total:** \(totalIncomplete) active, \(totalComplete) completed"

        return response
    }

    // MARK: - Productivity Streak

    @MainActor
    private func getProductivityStreak() async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        var currentStreak = 0
        var longestStreak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check backwards from today for current streak
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!

            let hasCompletion = allTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= checkDate && completedAt < nextDay
            }

            if hasCompletion {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        // Calculate longest streak (last 90 days)
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date())!
        var tempStreak = 0
        checkDate = ninetyDaysAgo

        while checkDate <= Date() {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!

            let hasCompletion = allTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= checkDate && completedAt < nextDay
            }

            if hasCompletion {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 0
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }

        var emoji = "🔥"
        var badge = ""
        if currentStreak >= 30 {
            emoji = "👑"
            badge = "Legendary!"
        } else if currentStreak >= 14 {
            emoji = "🏆"
            badge = "Amazing!"
        } else if currentStreak >= 7 {
            emoji = "⭐"
            badge = "Great streak!"
        } else if currentStreak >= 3 {
            emoji = "⚡"
            badge = "Building momentum!"
        } else if currentStreak == 0 {
            emoji = "💪"
        }

        var response = "\(emoji) **Productivity Streak**\n\n"

        if currentStreak == 0 {
            response += "No active streak.\n"
            response += "Complete a task today to start! 💪\n"
        } else {
            response += "🔥 **Current:** \(currentStreak) day(s) \(badge)\n"
        }

        response += "🏅 **Longest (90 days):** \(longestStreak) day(s)\n"

        // Motivational message
        if currentStreak > 0 {
            response += "\nKeep it going! Don't break the chain! 🔗"
        }

        return response
    }

    // MARK: - Best Productive Time

    @MainActor
    private func getBestProductiveTime() async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        // Group completions by hour
        var hourCounts: [Int: Int] = [:]
        for task in allTasks {
            guard let completedAt = task.completedAt, completedAt >= thirtyDaysAgo else { continue }
            let hour = calendar.component(.hour, from: completedAt)
            hourCounts[hour, default: 0] += 1
        }

        guard !hourCounts.isEmpty else {
            return "📊 Not enough data yet. Complete more tasks to see your productivity patterns!"
        }

        // Group into time periods
        let morning = (5..<12).reduce(0) { $0 + (hourCounts[$1] ?? 0) }     // 5am-12pm
        let afternoon = (12..<17).reduce(0) { $0 + (hourCounts[$1] ?? 0) }  // 12pm-5pm
        let evening = (17..<22).reduce(0) { $0 + (hourCounts[$1] ?? 0) }    // 5pm-10pm
        let night = (0..<5).reduce(0) { $0 + (hourCounts[$1] ?? 0) } + (22..<24).reduce(0) { $0 + (hourCounts[$1] ?? 0) }

        // Find peak hour
        let peakHour = hourCounts.max(by: { $0.value < $1.value })

        // Determine best period
        let periods = [
            ("🌅 Morning (5am-12pm)", morning),
            ("☀️ Afternoon (12pm-5pm)", afternoon),
            ("🌆 Evening (5pm-10pm)", evening),
            ("🌙 Night (10pm-5am)", night)
        ]
        let bestPeriod = periods.max(by: { $0.1 < $1.1 })!

        var response = "⏰ **Your Productivity Patterns**\n"
        response += "(Last 30 days)\n\n"

        // Bar chart style display
        let maxCount = max(morning, afternoon, evening, night, 1)
        for (name, count) in periods {
            let bars = String(repeating: "█", count: Int(Double(count) / Double(maxCount) * 10))
            let spaces = String(repeating: "░", count: 10 - bars.count)
            response += "\(name)\n  \(bars)\(spaces) \(count) tasks\n"
        }

        response += "\n**🎯 Peak time:** "
        if let peak = peakHour {
            let hourString = peak.key < 12 ? "\(peak.key)am" : (peak.key == 12 ? "12pm" : "\(peak.key - 12)pm")
            response += "\(hourString) (\(peak.value) tasks)"
        }

        response += "\n**💡 Best period:** \(bestPeriod.0.components(separatedBy: " ")[0]) "

        return response
    }

    // MARK: - Focus Stats

    @MainActor
    private func getFocusStats(listName: String?) async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        // Calculate total focus time from tasks
        let totalFocusSeconds = tasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }
        let totalFocusMinutes = totalFocusSeconds / 60
        let totalFocusHours = totalFocusMinutes / 60

        // Count tasks with focus time
        let tasksWithFocus = tasks.filter { $0.focusTimeSeconds > 0 }.count

        // Get focus sessions (if available in data model)
        // Note: This would need FocusSessionEntity queries

        var response = "🎯 **Focus Statistics**\n\n"

        if totalFocusSeconds == 0 {
            response += "No focus time recorded yet.\n"
            response += "Start a focus session to track your deep work!\n"
            response += "\n💡 Try: \"Start 25-minute focus on [task]\""
            return response
        }

        response += "⏱️ **Total focus time:** "
        if totalFocusHours > 0 {
            response += "\(totalFocusHours)h \(totalFocusMinutes % 60)m\n"
        } else {
            response += "\(totalFocusMinutes)m\n"
        }

        response += "📝 **Tasks with focus time:** \(tasksWithFocus)\n"

        if tasksWithFocus > 0 {
            let avgFocusPerTask = totalFocusMinutes / tasksWithFocus
            response += "📊 **Average per task:** \(avgFocusPerTask)m\n"
        }

        // Add encouragement
        if totalFocusMinutes >= 120 {
            response += "\n🌟 Great deep work! Keep up the focused effort!"
        }

        return response
    }

    // MARK: - Weekly Comparison

    @MainActor
    private func getWeeklyComparison() async -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "❌ Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!

        // This week's completions
        let thisWeek = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }.count

        // Last week's completions
        let lastWeek = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= twoWeeksAgo && completedAt < weekAgo
        }.count

        var response = "📊 **Weekly Comparison**\n\n"
        response += "📅 This week: \(thisWeek) tasks\n"
        response += "📅 Last week: \(lastWeek) tasks\n\n"

        if lastWeek == 0 {
            if thisWeek > 0 {
                response += "🚀 Great start this week!"
            } else {
                response += "💪 Time to get started!"
            }
        } else {
            let change = thisWeek - lastWeek
            let percentChange = Int((Double(change) / Double(lastWeek)) * 100)

            if change > 0 {
                response += "📈 **Up \(change) tasks (+\(percentChange)%)**\n"
                response += "🎉 Great improvement!"
            } else if change < 0 {
                response += "📉 **Down \(abs(change)) tasks (\(percentChange)%)**\n"
                response += "💪 Let's pick up the pace!"
            } else {
                response += "➡️ **Same as last week**\n"
                response += "📈 Push for more this week!"
            }
        }

        return response
    }

    @MainActor
    private func findList(_ name: String) -> TaskListEntity? {
        return AIToolHelpers.findList(name, dataService: dataService)
    }
}
```

#### System Prompt Section
```
ANALYTICS:
- When user asks about progress, statistics, productivity, or "how am I doing" → task_analytics
- Types:
  - daily_summary: Today's progress
  - weekly_summary: This week's trends
  - monthly_summary: Last 30 days
  - completion_rate: Overall completion %
  - overdue_count: Overdue tasks list
  - list_breakdown: Tasks per list
  - productivity_streak: Consecutive completion days
  - best_time: Most productive hours
  - focus_stats: Focus session statistics
  - weekly_comparison: This week vs last week
- Can filter by list name optionally
- Examples:
  - "how am I doing today?" → task_analytics(analyticsType: "daily_summary")
  - "my productivity streak" → task_analytics(analyticsType: "productivity_streak")
  - "when am I most productive?" → task_analytics(analyticsType: "best_time")
  - "compare this week to last" → task_analytics(analyticsType: "weekly_comparison")
```

---

### Tool 7: FocusSessionTool (Full Implementation)

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `focus_session` |
| Purpose | Start/stop Pomodoro focus sessions |
| RICE Score | 2.8 |
| Complexity | Medium |
| Dependencies | FocusTimerViewModel, FocusSessionEntity |

#### Natural Language Triggers
```
Start:
- "start focus on [task]"
- "focus on [task] for 25 minutes"
- "pomodoro [task]"
- "deep work on [task]"

Stop:
- "stop focus"
- "end session"
- "pause focus"

Status:
- "am I focusing?"
- "focus status"
- "how long have I been focusing?"
```

#### Full Implementation

```swift
//
//  FocusSessionTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for managing focus/Pomodoro sessions via LLM
struct FocusSessionTool: Tool {
    let name = "focus_session"

    let description = """
    Start, stop, or check status of focus sessions (Pomodoro). Use when user wants to focus on a task \
    for a set duration, or wants to know their current focus status.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Action: start, stop, or status")
        let action: String

        @Guide(description: "Task title to focus on (required for start action)")
        let taskTitle: String?

        @Guide(description: "Duration in minutes (default 25, common values: 15, 25, 45, 60)")
        let durationMinutes: Int?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeAction(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAction(arguments: Arguments) async -> String {
        switch arguments.action.lowercased() {
        case "start":
            return await startSession(arguments)
        case "stop":
            return await stopSession()
        case "status":
            return await getStatus()
        default:
            return "❌ Unknown action '\(arguments.action)'. Use: start, stop, or status."
        }
    }

    @MainActor
    private func startSession(_ arguments: Arguments) async -> String {
        // Check for task title
        guard let taskTitle = arguments.taskTitle, !taskTitle.isEmpty else {
            return "❌ Please specify which task to focus on."
        }

        // Find the task
        guard let task = AIToolHelpers.findTask(taskTitle, dataService: dataService) else {
            return "❌ Couldn't find a task matching '\(taskTitle)'."
        }

        // Check if task is completed
        if task.isCompleted {
            return "❌ '\(task.title ?? "Task")' is already completed. Choose an active task to focus on."
        }

        // Get duration (default 25 minutes)
        let duration = min(max(arguments.durationMinutes ?? 25, 5), 120) // 5-120 minutes

        // Post notification to start focus session
        NotificationCenter.default.post(
            name: .aiFocusSessionStart,
            object: nil,
            userInfo: [
                "taskId": task.id as Any,
                "taskTitle": task.title ?? "Task",
                "durationMinutes": duration
            ]
        )

        HapticManager.shared.success()

        let emoji = duration >= 45 ? "🎯" : "⏱️"
        var response = "\(emoji) **Focus session started!**\n"
        response += "📝 Task: \(task.title ?? "Task")\n"
        response += "⏱️ Duration: \(duration) minutes\n"
        response += "\nStay focused! Say \"stop focus\" when done."

        // Add tip based on duration
        if duration >= 45 {
            response += "\n\n💡 Long session - consider taking a 10-15 min break after."
        } else if duration == 25 {
            response += "\n\n💡 Classic Pomodoro! Take a 5 min break after."
        }

        return response
    }

    @MainActor
    private func stopSession() async -> String {
        // Post notification to stop focus session
        NotificationCenter.default.post(
            name: .aiFocusSessionStop,
            object: nil,
            userInfo: [:]
        )

        HapticManager.shared.lightImpact()

        return "⏹️ **Focus session ended.**\n\nGreat work! Take a short break before your next session. 🧘"
    }

    @MainActor
    private func getStatus() async -> String {
        // This would need to query the current focus session state from FocusTimerViewModel
        // For now, post a notification requesting status

        NotificationCenter.default.post(
            name: .aiFocusSessionStatus,
            object: nil,
            userInfo: [:]
        )

        // The response would come from the notification handler
        // This is a simplified version
        return "🔍 Checking focus session status...\n\n(Check the timer in the app header)"
    }
}

// MARK: - Focus Session Notifications
extension Notification.Name {
    static let aiFocusSessionStart = Notification.Name("aiFocusSessionStart")
    static let aiFocusSessionStop = Notification.Name("aiFocusSessionStop")
    static let aiFocusSessionStatus = Notification.Name("aiFocusSessionStatus")
}
```

#### System Prompt Section
```
FOCUS SESSIONS:
- When user wants to focus/concentrate on a task → focus_session with action="start"
- Common durations: 15 (quick), 25 (pomodoro), 45 (deep work), 60 (marathon)
- Default duration is 25 minutes
- Examples:
  - "focus on report" → focus_session(action: "start", taskTitle: "report")
  - "25 minute pomodoro on emails" → focus_session(action: "start", taskTitle: "emails", durationMinutes: 25)
  - "deep work on presentation for 45 minutes" → focus_session(action: "start", taskTitle: "presentation", durationMinutes: 45)
  - "stop focus" → focus_session(action: "stop")
  - "am I focusing?" → focus_session(action: "status")
```

---

## Phase 2: Batch Operations

### Tool 8: BatchOperationsTool

#### Overview
| Attribute | Value |
|-----------|-------|
| Name | `batch_operations` |
| Purpose | Perform bulk actions on multiple tasks |
| RICE Score | 1.35 |
| Complexity | High |
| Undo | Preview before execution |

#### Caution for Local LLMs
This tool has the highest complexity. Implementation deferred to Phase 2.

#### Implementation Outline

```swift
//
//  BatchOperationsTool.swift
//  Tasky
//

import Foundation
import FoundationModels

/// Tool for performing bulk operations on multiple tasks
struct BatchOperationsTool: Tool {
    let name = "batch_operations"

    let description = """
    Perform bulk operations on multiple tasks. Use when user wants to complete all, \
    reschedule multiple, or delete multiple tasks matching a filter. Use sparingly.
    """

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks: today, overdue, inbox, list:[name], high_priority, completed")
        let filter: String

        @Guide(description: "Action: complete_all, reschedule_all, delete_all")
        let action: String

        @Guide(description: "New date for reschedule_all: today, tomorrow, next_week, or ISO 8601 date")
        let newDate: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeOperation(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeOperation(arguments: Arguments) async -> String {
        // Get tasks matching filter
        guard let tasks = try? getTasksForFilter(arguments.filter) else {
            return "❌ Could not fetch tasks."
        }

        if tasks.isEmpty {
            return "ℹ️ No tasks match the filter '\(arguments.filter)'."
        }

        // Show preview before execution
        let previewCount = tasks.count
        let taskTitles = tasks.prefix(3).compactMap { $0.title }.joined(separator: ", ")
        let moreText = tasks.count > 3 ? " and \(tasks.count - 3) more" : ""

        switch arguments.action.lowercased() {
        case "complete_all":
            return await completeAll(tasks: tasks)
        case "reschedule_all":
            return await rescheduleAll(tasks: tasks, newDate: arguments.newDate)
        case "delete_all":
            return await deleteAll(tasks: tasks)
        default:
            return "❌ Unknown action '\(arguments.action)'. Use: complete_all, reschedule_all, or delete_all."
        }
    }

    // Implementation methods would follow...
    // Deferred to Phase 2
}
```

---

## System Prompt Architecture

### Complete Optimized System Prompt

```swift
private func buildSystemPrompt() -> String {
    let todayDateString = ISO8601DateFormatter().string(from: Date())
    let availableListsString = fetchAvailableListNames().joined(separator: ", ")

    return """
    You are Tasky's AI assistant. Help users manage tasks through natural conversation.

    TODAY: \(todayDateString)
    USER'S LISTS: \(availableListsString.isEmpty ? "None (tasks go to Inbox)" : availableListsString)

    ## TOOLS AVAILABLE

    CREATE: "add task", "create", "remind me"
    → create_tasks tool
    → Set dueDate to TODAY if not specified

    QUERY: "what's due", "show tasks", "how many"
    → query_tasks tool
    → Filters: today, tomorrow, upcoming, overdue, inbox, completed, high_priority, all, list:[name]

    COMPLETE: "done", "finished", "completed"
    → complete_task tool
    → completed=true for done, false for reopen

    UPDATE: "change", "rename", "set priority"
    → update_task tool
    → Priority: 0=none, 1=low, 2=medium, 3=high

    RESCHEDULE: "move to", "postpone", "reschedule"
    → reschedule_task tool
    → Options: today, tomorrow, next_week, next_month, weekday names

    DELETE: "delete", "remove", "cancel"
    → delete_task tool

    LISTS: "create list", "rename list", "delete list"
    → manage_list tool
    → Colors: red, orange, yellow, green, blue, purple, pink, gray

    ANALYTICS: "how am I doing", "my progress", "streak"
    → task_analytics tool
    → Types: daily_summary, weekly_summary, productivity_streak, best_time, completion_rate

    FOCUS: "focus on", "pomodoro", "deep work"
    → focus_session tool
    → Durations: 15, 25, 45, 60 minutes

    ## GUIDELINES

    1. Be concise - short confirmations
    2. Match tasks by title (partial matching)
    3. One tool call per user intent
    4. Use ISO 8601 for dates: YYYY-MM-DDTHH:MM:SSZ
    5. Default duration for focus: 25 minutes
    """
}
```

---

## Shared Infrastructure

### AIToolHelpers.swift

```swift
//
//  AIToolHelpers.swift
//  Tasky
//

import Foundation

/// Shared helper methods for AI tools
@MainActor
struct AIToolHelpers {

    // MARK: - Task Finding

    static func findTask(_ searchTitle: String, dataService: DataService) -> TaskEntity? {
        guard let allTasks = try? dataService.fetchAllTasks() else { return nil }
        let lowercased = searchTitle.lowercased().trimmingCharacters(in: .whitespaces)

        // Prefer incomplete tasks
        let incomplete = allTasks.filter { !$0.isCompleted }
        let searchPool = incomplete.isEmpty ? allTasks : incomplete

        // 1. Exact match
        if let exact = searchPool.first(where: { $0.title?.lowercased() == lowercased }) {
            return exact
        }

        // 2. Starts with
        if let prefix = searchPool.first(where: { $0.title?.lowercased().hasPrefix(lowercased) == true }) {
            return prefix
        }

        // 3. Contains
        if let partial = searchPool.first(where: { $0.title?.lowercased().contains(lowercased) == true }) {
            return partial
        }

        // 4. Word match
        let searchWords = Set(lowercased.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        if let wordMatch = searchPool.first(where: { task in
            guard let title = task.title?.lowercased() else { return false }
            let titleWords = Set(title.components(separatedBy: .whitespaces))
            return !searchWords.isDisjoint(with: titleWords)
        }) {
            return wordMatch
        }

        return nil
    }

    static func findSimilarTasks(_ searchTitle: String, dataService: DataService) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else { return "" }
        let lowercased = searchTitle.lowercased()

        let searchWords = Set(lowercased.components(separatedBy: .whitespaces))
        let similar = allTasks
            .filter { !$0.isCompleted }
            .filter { task in
                guard let title = task.title?.lowercased() else { return false }
                let titleWords = Set(title.components(separatedBy: .whitespaces))
                return !searchWords.isDisjoint(with: titleWords) ||
                       title.contains(lowercased) ||
                       lowercased.contains(title)
            }
            .prefix(3)
            .compactMap { $0.title }

        return similar.map { "• \($0)" }.joined(separator: "\n")
    }

    // MARK: - List Finding

    static func findList(_ name: String, dataService: DataService) -> TaskListEntity? {
        guard let lists = try? dataService.fetchAllTaskLists() else { return nil }
        let lowercased = name.lowercased()

        return lists.first(where: { $0.name.lowercased() == lowercased }) ??
               lists.first(where: { $0.name.lowercased().contains(lowercased) })
    }

    static func getAvailableListNames(dataService: DataService) -> String {
        guard let lists = try? dataService.fetchAllTaskLists() else { return "none" }
        return lists.map { $0.name }.joined(separator: ", ")
    }

    // MARK: - Date Parsing

    static func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        let formats: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate]
        ]

        for options in formats {
            formatter.formatOptions = options
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    static func calculateNewDate(_ when: String, specificDate: String?) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch when.lowercased() {
        case "today":
            return today
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "next_week":
            return calendar.date(byAdding: .day, value: 7, to: today)
        case "next_month":
            return calendar.date(byAdding: .month, value: 1, to: today)
        case "specific_date":
            guard let dateString = specificDate else { return nil }
            return parseISO8601Date(dateString)
        default:
            return parseWeekday(when)
        }
    }

    static func parseWeekday(_ day: String) -> Date? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                        "thursday": 5, "friday": 6, "saturday": 7]

        guard let targetWeekday = weekdays[day.lowercased()] else { return nil }

        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 { daysToAdd += 7 }

        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))
    }

    static func parseTime(_ timeString: String, onDate date: Date) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        let hour = components[0]
        let minute = components[1]

        guard hour >= 0, hour < 24, minute >= 0, minute < 60 else { return nil }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute

        return Calendar.current.date(from: dateComponents)
    }

    // MARK: - Date Formatting

    static func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        if calendar.isDateInYesterday(date) { return "yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
```

### AIToolNotifications.swift

```swift
//
//  AIToolNotifications.swift
//  Tasky
//

import Foundation

extension Notification.Name {
    // Task operations (with undo support)
    static let aiTasksCreated = Notification.Name("aiTasksCreated")
    static let aiTaskCompleted = Notification.Name("aiTaskCompleted")
    static let aiTaskUpdated = Notification.Name("aiTaskUpdated")
    static let aiTaskRescheduled = Notification.Name("aiTaskRescheduled")
    static let aiTaskDeleted = Notification.Name("aiTaskDeleted")

    // List operations
    static let aiListCreated = Notification.Name("aiListCreated")
    static let aiListUpdated = Notification.Name("aiListUpdated")
    static let aiListDeleted = Notification.Name("aiListDeleted")

    // Focus sessions
    static let aiFocusSessionStart = Notification.Name("aiFocusSessionStart")
    static let aiFocusSessionStop = Notification.Name("aiFocusSessionStop")
    static let aiFocusSessionStatus = Notification.Name("aiFocusSessionStatus")

    // Undo actions
    static let aiUndoAction = Notification.Name("aiUndoAction")
}
```

---

## Undo System Architecture

### 5-Second Undo Window Pattern

All AI operations that modify data support a 5-second undo window, consistent with the existing UI patterns.

```swift
/// UndoManager for AI operations
@MainActor
class AIUndoManager: ObservableObject {

    @Published var currentUndo: UndoableAction?
    @Published var showUndoToast = false

    private var undoTimer: Timer?

    struct UndoableAction {
        let type: ActionType
        let description: String
        let undoHandler: () -> Void
        let expiresAt: Date

        enum ActionType {
            case complete
            case update
            case reschedule
            case delete
            case listUpdate
            case listDelete
        }
    }

    func registerUndo(_ action: UndoableAction) {
        // Cancel any existing undo
        undoTimer?.invalidate()

        currentUndo = action
        showUndoToast = true

        // Set 5-second timer
        undoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.expireUndo()
            }
        }
    }

    func performUndo() {
        guard let action = currentUndo else { return }

        undoTimer?.invalidate()
        action.undoHandler()

        currentUndo = nil
        showUndoToast = false

        HapticManager.shared.lightImpact()
    }

    private func expireUndo() {
        currentUndo = nil
        showUndoToast = false
    }
}
```

### Usage in ViewModel

```swift
// In AIChatViewModel.swift

private func handleTaskCompleted(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let taskId = userInfo["taskId"] as? UUID,
          let taskTitle = userInfo["taskTitle"] as? String,
          let completed = userInfo["completed"] as? Bool,
          let previousState = userInfo["previousState"] as? Bool,
          let undoAvailable = userInfo["undoAvailable"] as? Bool,
          undoAvailable else { return }

    let action = AIUndoManager.UndoableAction(
        type: .complete,
        description: completed ? "Completed '\(taskTitle)'" : "Reopened '\(taskTitle)'",
        undoHandler: { [weak self] in
            // Revert to previous state
            if let task = try? self?.dataService.fetchTaskById(taskId) {
                try? self?.dataService.toggleTaskCompletion(task)
            }
        },
        expiresAt: Date().addingTimeInterval(5.0)
    )

    undoManager.registerUndo(action)
}
```

---

## UI/UX Patterns

### UndoToastView

```swift
/// Toast view showing undo option for 5 seconds
struct UndoToastView: View {
    @ObservedObject var undoManager: AIUndoManager
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if undoManager.showUndoToast, let action = undoManager.currentUndo {
            HStack {
                Text(action.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Button("Undo") {
                    undoManager.performUndo()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(reduceMotion ? .none : .spring(response: 0.3), value: undoManager.showUndoToast)
        }
    }
}
```

### Extended TaskPreviewCard

The existing TaskPreviewCard should be extended to show:
- Completed tasks with "Undo" option
- Updated tasks with change summary
- Rescheduled tasks with new date
- Deleted tasks with "Undo" option

---

## Implementation Checklist

### Phase 1: All Core Tools
- [ ] Create `AIToolHelpers.swift` with shared methods
- [ ] Create `AIToolNotifications.swift` with notification names
- [ ] Create `AIUndoManager.swift` for undo system
- [ ] Implement `CompleteTaskTool.swift`
- [ ] Implement `UpdateTaskTool.swift`
- [ ] Implement `RescheduleTaskTool.swift`
- [ ] Implement `DeleteTaskTool.swift`
- [ ] Implement `ManageListTool.swift`
- [ ] Implement `TaskAnalyticsTool.swift` (Rich version)
- [ ] Implement `FocusSessionTool.swift`
- [ ] Update `AIChatViewModel.setupSession()` to register all tools
- [ ] Update system prompt with all tool instructions
- [ ] Implement `UndoToastView` component
- [ ] Extend `TaskPreviewCard` for all action types
- [ ] Update `SuggestionEngine` with new suggestions

### Phase 2: Batch Operations
- [ ] Implement `BatchOperationsTool.swift`
- [ ] Add preview/confirmation UI for batch operations

---

## Files Summary

### New Files to Create (Phase 1)
| File | Description |
|------|-------------|
| `AIToolHelpers.swift` | Shared helper methods |
| `AIToolNotifications.swift` | Notification name extensions |
| `AIUndoManager.swift` | 5-second undo manager |
| `CompleteTaskTool.swift` | Mark tasks complete/incomplete |
| `UpdateTaskTool.swift` | Edit task properties |
| `RescheduleTaskTool.swift` | Change task dates |
| `DeleteTaskTool.swift` | Remove tasks |
| `ManageListTool.swift` | List CRUD operations |
| `TaskAnalyticsTool.swift` | Rich productivity statistics |
| `FocusSessionTool.swift` | Pomodoro integration |
| `UndoToastView.swift` | Undo UI component |

### Files to Modify
| File | Changes |
|------|---------|
| `AIChatViewModel.swift` | Register all tools, handle notifications, integrate undo manager |
| `AIChatView.swift` | Add UndoToastView overlay |
| `SuggestionEngine.swift` | Add suggestions for new capabilities |
| `TaskPreviewCard.swift` | Extend for all action feedback types |

---

## Success Criteria

| Tool | Key Metric | Target |
|------|------------|--------|
| CompleteTaskTool | Task match success rate | > 90% |
| UpdateTaskTool | Fields updated correctly | > 95% |
| RescheduleTaskTool | Date parsing accuracy | > 95% |
| DeleteTaskTool | Undo usage rate | > 10% (validates visibility) |
| ManageListTool | List operation success | > 95% |
| TaskAnalyticsTool | Response relevance | > 85% |
| FocusSessionTool | Session start success | > 95% |

---

*Document Version: 2.0*
*Last Updated: November 2025*
*Decisions: All tools in Phase 1, 5-second undo, Rich analytics, Full focus sessions*
