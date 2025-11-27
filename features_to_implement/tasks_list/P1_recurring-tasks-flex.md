# Flexible Recurring Tasks

**Priority:** P1
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Current recurrence only supports basic daily/weekly patterns. Users cannot express "every 2 weeks", "first Monday of month", "every weekday", or "3 days after completion". This is table stakes for task apps.

## Requirements

### Must Have
- [ ] Extend recurrence model to support flexible patterns
- [ ] Daily: every N days
- [ ] Weekly: every N weeks, specific days (Mon, Wed, Fri)
- [ ] Monthly: specific date OR relative (first Monday, last Friday)
- [ ] "After completion" mode: next occurrence N days after completion
- [ ] Recurrence picker UI with pattern preview
- [ ] Show recurrence indicator on task row
- [ ] Generate next occurrence on completion

### Should Have
- [ ] Yearly recurrence (birthdays, anniversaries)
- [ ] End date for recurrence (stop after date X)
- [ ] Count limit (repeat only N times)
- [ ] Skip occurrence option
- [ ] Natural language recurrence in AI ("every other Tuesday")

## Recurrence Patterns

| Pattern | Example | Data Model |
|---------|---------|------------|
| Every N days | Every 3 days | interval: 3, unit: day |
| Weekly on days | Mon, Wed, Fri | interval: 1, unit: week, days: [2,4,6] |
| Every N weeks | Every 2 weeks | interval: 2, unit: week |
| Monthly date | 15th of month | interval: 1, unit: month, dayOfMonth: 15 |
| Monthly relative | First Monday | interval: 1, unit: month, weekday: 2, ordinal: 1 |
| After completion | 3 days after done | afterCompletion: true, interval: 3 |

## Components Affected

### Files to Modify
- `Tasky.xcdatamodeld` - Extend recurrence fields on TaskEntity
- `Models/TaskEntity+Extensions.swift` - Recurrence calculation logic
- `Views/Tasks/TaskDetailView.swift` - Add recurrence picker
- `Services/TaskService.swift` - Handle occurrence generation

### Files to Create
- `Models/RecurrencePattern.swift` - Recurrence pattern model
- `Views/Tasks/RecurrencePickerView.swift` - Pattern selection UI
- `Services/RecurrenceService.swift` - Next occurrence calculation

## Key Notes
- Recurrence calculation is date math heavy - test edge cases (month ends, leap years)
- "After completion" is fundamentally different from calendar-based
- Consider timezone handling for users who travel
- Show human-readable pattern summary ("Every Monday and Wednesday")
