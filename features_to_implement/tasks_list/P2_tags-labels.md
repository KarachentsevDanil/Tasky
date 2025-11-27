# Tags & Labels System

**Priority:** P2
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Tasks belong to only one list. Cannot categorize across dimensions (context: #home/#office, energy: #quickwin/#deepwork, people: #sarah). Power users want flexible filtering.

## Requirements

### Must Have
- [ ] Create TagEntity: id, name, color
- [ ] Many-to-many relationship: Task ↔ Tags
- [ ] Tag picker in task detail view
- [ ] Create tag inline while tagging
- [ ] Filter by tag in task list
- [ ] Tag management in settings (rename, delete, merge)
- [ ] Show tags on task row (colored pills)

### Should Have
- [ ] AI suggests tags based on task content
- [ ] "queryTasks" tool filters by tag
- [ ] Tag-based smart lists
- [ ] Bulk add/remove tags

## Components Affected

### Files to Create
- `Models/TagEntity.swift` - Tag Core Data entity
- `Views/Tasks/TagPickerView.swift` - Tag selection UI
- `Views/Tasks/TagPillView.swift` - Tag display component
- `Views/Settings/TagManagementView.swift` - Tag CRUD

### Files to Modify
- `Tasky.xcdatamodeld` - Add TagEntity, many-to-many relationship
- `Views/Tasks/TaskDetailView.swift` - Add tag picker section
- `Views/Tasks/TaskRowView.swift` - Display tags inline
- `Services/AI/Tools/QueryTasksTool.swift` - Add tag filtering

## Key Notes
- Limit visible tags per task (3-4 max) to avoid clutter
- Consider predefined starter tags vs blank slate
- Tags are cross-list by design (unlike lists)
- Core Data migration required
