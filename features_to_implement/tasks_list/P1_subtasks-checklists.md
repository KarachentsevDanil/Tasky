# Subtasks & Checklists

**Priority:** P1
**View Area:** global
**Status:** NOT_STARTED

## Problem
Users cannot break down large tasks into steps. The suggestBreakdown AI tool generates ideas but cannot create actual subtasks. Big tasks get perpetually postponed because they feel overwhelming.

## Requirements

### Must Have
- [ ] Add subtasks relationship to TaskEntity (one level deep, no nesting)
- [ ] Create SubtaskEntity with: id, title, isCompleted, sortOrder, parentTask
- [ ] Display subtasks as checklist within task detail view
- [ ] Allow inline subtask creation (tap to add)
- [ ] Allow subtask completion via checkbox tap
- [ ] Show progress indicator on parent task (3/7 format or progress ring)
- [ ] Complete parent task option when all subtasks done
- [ ] Allow subtask reordering via drag
- [ ] Allow subtask deletion via swipe

### Should Have
- [ ] suggestBreakdown tool creates actual subtasks (not just text suggestions)
- [ ] Convert subtask to standalone task
- [ ] Duplicate subtasks when duplicating parent task
- [ ] Subtask count visible in task list row

## Components Affected

### Files to Modify
- `Tasky.xcdatamodeld` - Add SubtaskEntity, relationship to TaskEntity
- `Models/TaskEntity+Extensions.swift` - Add subtask helpers
- `Views/Tasks/TaskDetailView.swift` - Add subtask section
- `Services/AI/Tools/SuggestBreakdownTool.swift` - Create actual subtasks

### Files to Create
- `Models/SubtaskEntity+Extensions.swift` - Subtask model extensions
- `Views/Tasks/SubtaskRowView.swift` - Individual subtask row
- `Views/Tasks/SubtaskListView.swift` - Subtask checklist component
- `ViewModels/SubtaskViewModel.swift` - Subtask CRUD operations

## Key Notes
- Keep to ONE level of nesting only (subtasks cannot have subtasks)
- Core Data migration required - test with existing data
- Progress calculation: completedSubtasks.count / allSubtasks.count
- Consider: should completing all subtasks auto-complete parent?
