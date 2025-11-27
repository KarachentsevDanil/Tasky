# Task Dependencies

**Priority:** P2
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Cannot express "do X before Y" relationships. Planning puts dependent tasks in wrong order. Completing a blocker doesn't surface newly-unblocked tasks.

## Requirements

### Must Have
- [ ] Add "blockedBy" relationship on TaskEntity (self-referential)
- [ ] UI to set blocker task
- [ ] Visual indicator for blocked tasks (lock icon, grayed out)
- [ ] Filter view: "Blocked" vs "Actionable"
- [ ] Notification when blocker completed ("X is now unblocked")
- [ ] Prevent circular dependencies

### Should Have
- [ ] AI respects dependencies in planning
- [ ] "queryTasks" can filter actionable-only
- [ ] Dependency chain visualization
- [ ] Bulk unblock

## Components Affected

### Files to Modify
- `Tasky.xcdatamodeld` - Add blockedBy self-referential relationship
- `Models/TaskEntity+Extensions.swift` - Dependency helpers, cycle detection
- `Views/Tasks/TaskDetailView.swift` - Blocker picker section
- `Views/Tasks/TaskRowView.swift` - Blocked indicator (lock icon)
- `Services/AI/Tools/PlanDayTool.swift` - Respect dependencies in ordering

### Files to Create
- `Views/Tasks/BlockerPickerView.swift` - Select blocking task UI
- `Services/DependencyService.swift` - Cycle detection, unblock notifications

## Key Notes
- Keep simple: one-level blocking only (A blocks B, not deep chains)
- Must validate no circular references (A blocks B blocks A)
- Blocked tasks should be visually distinct but still visible
- Consider: should blocked tasks appear in Today view?
