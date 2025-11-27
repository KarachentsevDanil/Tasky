# Tasks List Features Implementation Plan

## Overview

Implementing 4 features from the tasks_list folder:
- **P1**: Subtasks & Checklists
- **P1**: Flexible Recurring Tasks
- **P2**: Bulk Operations
- **P2**: Tags & Labels

## Implementation Order

Features will be implemented in this order based on dependencies:
1. **Tags & Labels (P2)** - No dependencies, foundational for filtering
2. **Subtasks & Checklists (P1)** - Core feature, affects task detail view
3. **Flexible Recurring Tasks (P1)** - Extends existing recurrence
4. **Bulk Operations (P2)** - Requires tags for full functionality

---

## Phase 1: Tags & Labels

### 1.1 Core Data Changes
- [ ] Add `TagEntity` to `TaskTracker.xcdatamodeld`:
  - `id: UUID` (required)
  - `name: String` (required)
  - `colorHex: String` (optional)
  - `sortOrder: Int16` (default 0)
  - `createdAt: Date` (required)
- [ ] Add many-to-many relationship: `TaskEntity.tags ↔ TagEntity.tasks`
- [ ] Create `TagEntity+CoreDataClass.swift`
- [ ] Create `TagEntity+CoreDataProperties.swift`

### 1.2 Data Service
- [ ] Add tag CRUD operations to `DataService`:
  - `createTag(name:colorHex:)`
  - `updateTag(_:name:colorHex:)`
  - `deleteTag(_:)`
  - `fetchAllTags()`
- [ ] Add tag-task operations:
  - `addTag(_:to:)`
  - `removeTag(_:from:)`
  - `fetchTasks(withTag:)`

### 1.3 ViewModel Updates
- [ ] Add `@Published var tags: [TagEntity]` to `TaskListViewModel`
- [ ] Add `loadTags()` method
- [ ] Add tag filter to `FilterType` enum: `.tag(TagEntity)`
- [ ] Update `createTask` and `updateTask` to accept tags

### 1.4 UI Components
- [ ] Create `TagPillView.swift` - Small colored tag display
- [ ] Create `TagPickerView.swift` - Tag selection for task detail
- [ ] Create `TagManagementView.swift` - Settings view for tag CRUD
- [ ] Update `TaskRowView.swift` - Show tag pills (max 3)
- [ ] Update `TaskDetailView.swift` - Add tag picker row

---

## Phase 2: Subtasks & Checklists

### 2.1 Core Data Changes
- [ ] Add `SubtaskEntity` to `TaskTracker.xcdatamodeld`:
  - `id: UUID` (required)
  - `title: String` (required)
  - `isCompleted: Bool` (default false)
  - `sortOrder: Int16` (default 0)
  - `createdAt: Date` (required)
  - `completedAt: Date?` (optional)
- [ ] Add relationship: `TaskEntity.subtasks ↔ SubtaskEntity.parentTask`
  - One-to-many, cascade delete
- [ ] Create `SubtaskEntity+CoreDataClass.swift`
- [ ] Create `SubtaskEntity+CoreDataProperties.swift`

### 2.2 Data Service
- [ ] Add subtask operations to `DataService`:
  - `createSubtask(title:for:)`
  - `updateSubtask(_:title:)`
  - `toggleSubtaskCompletion(_:)`
  - `deleteSubtask(_:)`
  - `reorderSubtasks(_:)`

### 2.3 Task Extensions
- [ ] Add computed properties to `TaskEntity`:
  - `subtasksArray: [SubtaskEntity]` - Sorted by sortOrder
  - `subtasksProgress: (completed: Int, total: Int)`
  - `subtasksProgressString: String` - "3/7"
  - `allSubtasksCompleted: Bool`

### 2.4 UI Components
- [ ] Create `SubtaskRowView.swift` - Individual subtask with checkbox
- [ ] Create `SubtaskListView.swift` - List of subtasks with add button
- [ ] Create `SubtaskProgressView.swift` - Progress ring or bar
- [ ] Update `TaskRowView.swift` - Show subtask count indicator
- [ ] Update `TaskDetailView.swift` - Add subtask section between notes and date

---

## Phase 3: Flexible Recurring Tasks

### 3.1 Core Data Changes
- [ ] Add new fields to `TaskEntity`:
  - `recurrenceType: String` (daily/weekly/monthly/yearly/afterCompletion)
  - `recurrenceInterval: Int16` (every N units)
  - `recurrenceDayOfMonth: Int16` (for monthly)
  - `recurrenceWeekdayOrdinal: Int16` (1st, 2nd, 3rd, last)
  - `recurrenceEndDate: Date?` (optional end date)
  - `recurrenceCount: Int16` (max occurrences, 0 = unlimited)
  - `completedOccurrences: Int16` (track completed count)

### 3.2 Recurrence Model
- [ ] Create `RecurrencePattern.swift`:
  - Enum `RecurrenceType`: daily, weekly, monthly, yearly, afterCompletion
  - Struct `RecurrencePattern` with all configuration
  - Method `nextOccurrence(from:)` - Calculate next date
  - Method `humanReadableDescription` - "Every Monday and Wednesday"

### 3.3 Recurrence Service
- [ ] Create `RecurrenceService.swift`:
  - `calculateNextOccurrence(for:from:)`
  - `shouldGenerateOccurrence(for:)`
  - `generateNextOccurrence(for:)` - Creates new task instance

### 3.4 UI Components
- [ ] Create `RecurrencePickerView.swift`:
  - Type selector (daily/weekly/monthly/yearly)
  - Interval picker (every N days/weeks/etc)
  - Weekday picker (for weekly)
  - Day of month picker (for monthly)
  - Ordinal picker (first Monday, last Friday)
  - End condition (never, on date, after N occurrences)
- [ ] Update `WeekdaySelector.swift` - Support new patterns
- [ ] Update `TaskDetailView.swift` - Replace repeat row with new picker
- [ ] Update `TaskRowView.swift` - Show recurrence indicator

### 3.5 Task Completion Logic
- [ ] Update `toggleTaskCompletion` in `DataService`:
  - Check if recurring
  - If "afterCompletion" type, schedule next from completion date
  - If calendar-based, generate next occurrence if needed
  - Track completedOccurrences count

---

## Phase 4: Bulk Operations

### 4.1 ViewModel State
- [ ] Add to `TaskListViewModel`:
  - `@Published var isMultiSelectMode: Bool = false`
  - `@Published var selectedTaskIds: Set<UUID> = []`
  - Methods: `enterMultiSelectMode()`, `exitMultiSelectMode()`
  - Methods: `selectTask(_:)`, `deselectTask(_:)`, `selectAll()`, `deselectAll()`
  - `var selectedTasksCount: Int`

### 4.2 Bulk Operations
- [ ] Add bulk methods to `TaskListViewModel`:
  - `bulkComplete()` - Mark all selected as complete
  - `bulkDelete()` - Delete all selected (with confirmation)
  - `bulkReschedule(to:)` - Move to new date
  - `bulkMoveToList(_:)` - Move to list
  - `bulkSetPriority(_:)` - Set priority
  - `bulkAddTag(_:)` - Add tag to all (if tags implemented)

### 4.3 Undo Support
- [ ] Create `BulkOperationUndo` struct:
  - Store affected task IDs and previous states
  - `undoBulkComplete()`, `undoBulkDelete()`, etc.
- [ ] Add `@Published var canUndoBulkOperation: Bool`

### 4.4 UI Components
- [ ] Create `BulkActionBar.swift`:
  - Floating bar at bottom during multi-select
  - Buttons: Complete, Delete, Reschedule, Move, Priority
  - Selection count indicator
  - "Done" button to exit mode
- [ ] Create `BulkDatePickerSheet.swift` - Date picker for bulk reschedule
- [ ] Create `BulkListPickerSheet.swift` - List picker for bulk move
- [ ] Create `BulkPriorityPickerSheet.swift` - Priority picker for bulk set

### 4.5 TaskListView Updates
- [ ] Update `TaskListView.swift`:
  - Long press gesture to enter multi-select
  - Selection checkmarks on rows during multi-select
  - Overlay bulk action bar when in mode
  - Disable navigation during multi-select

### 4.6 TaskRowView Updates
- [ ] Update `TaskRowView.swift`:
  - Add `isMultiSelectMode: Bool` parameter
  - Add `isSelected: Bool` parameter
  - Show selection checkbox instead of completion checkbox when in mode
  - Different visual style during multi-select

---

## Files Summary

### New Files to Create
```
Models/
  TagEntity+CoreDataClass.swift
  TagEntity+CoreDataProperties.swift
  SubtaskEntity+CoreDataClass.swift
  SubtaskEntity+CoreDataProperties.swift
  RecurrencePattern.swift

Services/
  RecurrenceService.swift

Features/Tasks/Views/Components/
  TagPillView.swift
  TagPickerView.swift
  SubtaskRowView.swift
  SubtaskListView.swift
  SubtaskProgressView.swift
  RecurrencePickerView.swift
  BulkActionBar.swift
  BulkDatePickerSheet.swift
  BulkListPickerSheet.swift
  BulkPriorityPickerSheet.swift

Features/Settings/Views/
  TagManagementView.swift
```

### Files to Modify
```
TaskTracker.xcdatamodeld - Add TagEntity, SubtaskEntity, new TaskEntity fields
TaskEntity+CoreDataProperties.swift - Add new relationships and fields
DataService.swift - Add tag/subtask/recurrence operations
TaskListViewModel.swift - Add tags, multi-select state, bulk operations
TaskRowView.swift - Tags display, subtask count, multi-select mode
TaskDetailView.swift - Tag picker, subtask section, new recurrence picker
TaskListView.swift - Multi-select mode, bulk action bar
Constants.swift - Add new constants for tags, limits
PersistenceController.swift - Update preview data
```

---

## Estimated Effort

| Feature | Components | Complexity |
|---------|------------|------------|
| Tags & Labels | 8 | Medium |
| Subtasks | 7 | Medium |
| Recurring Tasks | 6 | High (date math) |
| Bulk Operations | 10 | Medium |

---

## Implementation Notes

### Core Data Migration
- All schema changes should be done together to minimize migrations
- Test with existing data after migration
- Use lightweight migration where possible

### Performance Considerations
- Lazy load subtasks (only when expanding task detail)
- Batch fetch tags with tasks to avoid N+1
- Limit bulk operations to 100 tasks at a time
- Use background context for bulk operations

### UX Guidelines
- Tags: Max 3 visible on row, show "+N" for more
- Subtasks: Max 10 per task to keep focused
- Multi-select: Visual feedback on selection
- Bulk operations: Confirmation for destructive actions
- Haptic feedback on all bulk actions

### Testing Priority
1. Core Data relationships and migrations
2. Recurrence date calculations (edge cases)
3. Bulk operations undo/redo
4. Tag filtering with existing filters
