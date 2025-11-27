# Goal Progress Tracking

**Priority:** P3
**View Area:** settings
**Status:** NOT_STARTED

## Problem
Goals exist in ContextStore but have no progress visualization. Users cannot see "Launch project: 40% complete" or track velocity toward goals.

## Requirements

### Must Have
- [ ] Explicit goal-task linking (tag task with goal)
- [ ] Goal progress calculation (completed / total linked tasks)
- [ ] Goal list view with progress bars
- [ ] Goal detail view showing linked tasks
- [ ] Goal creation/editing UI

### Should Have
- [ ] Goal velocity: "At current pace, done by Feb 15"
- [ ] Goal timeline visualization
- [ ] Weekly goal progress in analytics
- [ ] Goal neglect warnings (no progress in X days)
- [ ] Goal target date with countdown
- [ ] Archive completed goals

## Goal Data Model

### GoalEntity (or extend UserContextEntity)
| Field | Type | Purpose |
|-------|------|---------|
| id | UUID | Unique identifier |
| name | String | Goal name |
| targetDate | Date? | Optional deadline |
| status | String | active, paused, completed, abandoned |
| createdAt | Date | When created |
| tasks | [TaskEntity] | Linked tasks (relationship) |

## Progress Calculation

```
progress = completedLinkedTasks.count / allLinkedTasks.count

velocity = completedThisWeek / 7 (tasks per day)
estimatedCompletion = today + (remainingTasks / velocity)
```

## Components Affected

### Files to Create
- `Models/GoalEntity.swift` - Goal Core Data entity (or extend context)
- `Views/Goals/GoalsListView.swift` - All goals with progress
- `Views/Goals/GoalDetailView.swift` - Goal tasks and stats
- `Views/Goals/GoalEditorView.swift` - Create/edit goal
- `Views/Goals/GoalProgressBar.swift` - Visual progress component
- `ViewModels/GoalsViewModel.swift` - Goal logic

### Files to Modify
- `Tasky.xcdatamodeld` - Add GoalEntity or extend schema
- `Views/Tasks/TaskDetailView.swift` - Goal picker/linker
- `Views/Progress/AnalyticsView.swift` - Goal progress section
- `Services/AI/Tools/CreateTasksTool.swift` - Auto-link to detected goals

## Key Notes
- Decide: separate GoalEntity or use ContextStore goals?
- Tasks can link to multiple goals (many-to-many)
- Consider: should AI auto-detect goal relevance?
- Goal abandonment is okay - don't guilt users
- Integrate with Weekly Review flow
