# Weekly Review Flow

**Priority:** P2
**View Area:** settings
**Status:** NOT_STARTED

## Problem
No structured way to reflect on the week, handle incomplete tasks, and plan ahead. Users must manually review, leading to task pile-up and lost insights.

## Requirements

### Must Have
- [ ] Weekly review prompt (Sunday evening notification, configurable)
- [ ] Guided review flow with steps:
  1. Celebrate: Show completed tasks count + wins
  2. Incomplete: Review what didn't get done (delete/defer/keep)
  3. Overdue: Triage overdue tasks
  4. Upcoming: Preview next week
- [ ] Quick actions per task: delete, move to next week, keep
- [ ] Review completion summary
- [ ] Track review streak (weeks in a row)

### Should Have
- [ ] AI summary of the week ("You completed 23 tasks, focused 4.5 hours")
- [ ] Goal progress check-in
- [ ] "What blocked you?" capture (free text)
- [ ] Comparison to previous weeks
- [ ] Custom review day/time
- [ ] Skip review option (with gentle nudge next week)

## Review Flow Steps

| Step | Screen | Actions |
|------|--------|---------|
| 1. Celebrate | "You completed 18 tasks! 🎉" | Continue |
| 2. Incomplete | List of incomplete tasks | Delete / Next Week / Keep |
| 3. Overdue | List of overdue tasks | Delete / Reschedule / Keep |
| 4. Upcoming | Next week preview | Add task / Done |
| 5. Summary | Review complete, streak count | Close |

## Components Affected

### Files to Create
- `Views/Review/WeeklyReviewView.swift` - Review flow container
- `Views/Review/ReviewCelebrateStep.swift` - Wins celebration
- `Views/Review/ReviewIncompleteStep.swift` - Incomplete task triage
- `Views/Review/ReviewOverdueStep.swift` - Overdue task triage
- `Views/Review/ReviewUpcomingStep.swift` - Next week preview
- `Views/Review/ReviewSummaryStep.swift` - Completion summary
- `ViewModels/WeeklyReviewViewModel.swift` - Review flow logic
- `Services/WeeklyReviewService.swift` - Scheduling, streak tracking

### Files to Modify
- `Services/NotificationService.swift` - Weekly review reminder
- `Views/Settings/SettingsView.swift` - Review day/time config
- `Models/UserDefaults+Extensions.swift` - Store review preferences, streak

## Key Notes
- Make it feel like reflection, not a chore
- Should take 5-10 minutes max
- Celebrate accomplishments BEFORE showing problems
- Rolling over tasks indefinitely should feel intentional
- Default: Sunday 6:00 PM (configurable)
