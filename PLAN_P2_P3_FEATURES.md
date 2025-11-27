# Implementation Plan: P2 Weekly Review & P3 Goal Progress

## Overview

This plan covers the implementation of two Settings-related features:
- **P2: Weekly Review Flow** - Guided weekly reflection with task triage
- **P3: Goal Progress Tracking** - Goal-task linking with progress visualization

---

## P2: Weekly Review Flow

### Architecture Decision
Use a **standalone multi-step flow** (similar to onboarding) with ViewModel managing state. The review is triggered from Settings and presents as a full-screen modal.

### Files to Create

```
Features/WeeklyReview/
├── ViewModels/
│   └── WeeklyReviewViewModel.swift      # Flow state, data loading, actions
├── Views/
│   ├── Screens/
│   │   └── WeeklyReviewFlowView.swift   # Container with step navigation
│   └── Components/
│       ├── ReviewCelebrateStep.swift    # Step 1: Show wins
│       ├── ReviewIncompleteStep.swift   # Step 2: Triage incomplete tasks
│       ├── ReviewOverdueStep.swift      # Step 3: Triage overdue tasks
│       ├── ReviewUpcomingStep.swift     # Step 4: Preview next week
│       └── ReviewSummaryStep.swift      # Step 5: Completion summary
└── Services/
    └── WeeklyReviewService.swift        # Streak tracking, scheduling
```

### Files to Modify

1. **SettingsView.swift** - Add "Weekly Review" section with:
   - Start Review button
   - Review day/time picker
   - Streak display
   - Next scheduled review date

2. **NotificationManager.swift** - Add weekly review reminder scheduling

3. **Constants.swift** - Add WeeklyReview constants

### Data Storage (UserDefaults)

```swift
@AppStorage("weeklyReviewEnabled") var weeklyReviewEnabled = true
@AppStorage("weeklyReviewDay") var weeklyReviewDay = 1        // 1=Sunday
@AppStorage("weeklyReviewHour") var weeklyReviewHour = 18     // 6 PM
@AppStorage("weeklyReviewStreak") var weeklyReviewStreak = 0
@AppStorage("lastWeeklyReviewDate") var lastWeeklyReviewDate: Date?
```

### Flow Steps

| Step | Title | Data Shown | Actions |
|------|-------|------------|---------|
| 1 | Celebrate | Completed count, focus time, streak | Continue |
| 2 | Incomplete | Tasks not done this week | Delete / Next Week / Keep |
| 3 | Overdue | Overdue tasks | Delete / Reschedule / Keep |
| 4 | Upcoming | Tasks for next week | Add Task / Done |
| 5 | Summary | Review complete, new streak | Close |

### UI Design

- Full-screen modal presentation
- PageTabView with custom progress indicator
- Swipe navigation between steps
- Each step has action buttons at bottom
- Celebration step uses confetti animation

---

## P3: Goal Progress Tracking

### Architecture Decision

**Create new GoalEntity** (not extend UserContextEntity) because:
1. Goals need many-to-many relationship with tasks
2. Goals require progress calculation from linked tasks
3. UserContextEntity is for AI context/memory, not structured data
4. Separate entity provides cleaner querying and relationships

### Core Data Changes

#### New Entity: GoalEntity

```xml
<entity name="GoalEntity" representedClassName="GoalEntity" syncable="YES">
    <attribute name="id" attributeType="UUID"/>
    <attribute name="name" attributeType="String"/>
    <attribute name="notes" optional="YES" attributeType="String"/>
    <attribute name="targetDate" optional="YES" attributeType="Date"/>
    <attribute name="status" attributeType="String" defaultValueString="active"/>
    <attribute name="colorHex" optional="YES" attributeType="String"/>
    <attribute name="iconName" optional="YES" attributeType="String"/>
    <attribute name="createdAt" attributeType="Date"/>
    <attribute name="completedAt" optional="YES" attributeType="Date"/>
    <relationship name="tasks" optional="YES" toMany="YES" destinationEntity="TaskEntity" inverseName="goals" inverseEntity="TaskEntity"/>
</entity>
```

#### Modify TaskEntity

Add inverse relationship:
```xml
<relationship name="goals" optional="YES" toMany="YES" destinationEntity="GoalEntity" inverseName="tasks" inverseEntity="GoalEntity"/>
```

### Files to Create

```
Features/Goals/
├── ViewModels/
│   └── GoalsViewModel.swift            # Goal CRUD, progress calculation
├── Views/
│   ├── Screens/
│   │   ├── GoalsListView.swift         # All goals with progress bars
│   │   └── GoalDetailView.swift        # Goal tasks and stats
│   └── Components/
│       ├── GoalProgressBar.swift       # Visual progress component
│       ├── GoalRow.swift               # List row component
│       └── GoalEditorSheet.swift       # Create/edit goal sheet
Core/Models/
├── GoalEntity+CoreDataClass.swift
└── GoalEntity+CoreDataProperties.swift
```

### Files to Modify

1. **TaskTracker.xcdatamodeld** - Add GoalEntity, modify TaskEntity

2. **DataService.swift** - Add goal CRUD operations:
   - `createGoal()`
   - `updateGoal()`
   - `deleteGoal()`
   - `fetchAllGoals()`
   - `fetchGoalProgress()`
   - `linkTaskToGoal()`
   - `unlinkTaskFromGoal()`

3. **SettingsView.swift** - Add Goals navigation link

4. **AddTaskView.swift** / **TaskDetailView.swift** - Add goal picker

### Progress Calculation

```swift
extension GoalEntity {
    var progress: Double {
        let allTasks = linkedTasks
        guard !allTasks.isEmpty else { return 0 }
        let completedCount = allTasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(allTasks.count)
    }

    var estimatedCompletion: Date? {
        // Based on velocity: tasks completed per day this week
        guard progress > 0, progress < 1 else { return nil }
        let velocity = weeklyCompletionVelocity
        let remaining = linkedTasks.filter { !$0.isCompleted }.count
        let daysToComplete = Double(remaining) / velocity
        return Calendar.current.date(byAdding: .day, value: Int(daysToComplete), to: Date())
    }
}
```

### Goal Status Enum

```swift
enum GoalStatus: String, CaseIterable, Codable {
    case active
    case paused
    case completed
    case abandoned
}
```

### UI Design

**GoalsListView:**
- List of goals with progress bars
- Swipe to archive/delete
- FAB to add new goal
- Empty state when no goals

**GoalDetailView:**
- Progress ring at top
- Velocity indicator ("At current pace: done by Feb 15")
- List of linked tasks (toggle completion inline)
- Add task to goal button
- Edit goal button

**GoalEditorSheet:**
- Name text field
- Target date picker (optional)
- Color picker
- Icon picker

---

## Implementation Order

### Phase 1: P2 Weekly Review (Simpler, no Core Data changes)
1. Create WeeklyReviewService with UserDefaults persistence
2. Create WeeklyReviewViewModel
3. Create step components (5 views)
4. Create WeeklyReviewFlowView container
5. Update SettingsView with review section
6. Add notification scheduling

### Phase 2: P3 Goal Progress
1. Update Core Data model (GoalEntity)
2. Generate Core Data classes
3. Add DataService goal operations
4. Create GoalsViewModel
5. Create GoalProgressBar component
6. Create GoalRow component
7. Create GoalsListView
8. Create GoalDetailView
9. Create GoalEditorSheet
10. Update SettingsView with goals link
11. (Optional) Add goal picker to task views

---

## Estimated Complexity

| Feature | New Files | Modified Files | Core Data | Difficulty |
|---------|-----------|----------------|-----------|------------|
| P2 Weekly Review | 8 | 3 | None | Medium |
| P3 Goals | 9 | 5 | Yes | Medium-High |

---

## Questions/Decisions Needed

1. **Weekly Review notification**: Should it be a standard notification or a Live Activity?
   - **Decision**: Standard notification (simpler, matches app style)

2. **Goal-Task linking**: Can a task belong to multiple goals?
   - **Decision**: Yes, many-to-many relationship (spec says "Tasks can link to multiple goals")

3. **Goal in AddTaskView**: Show goal picker inline or as separate step?
   - **Decision**: Inline NavigationRow (consistent with list picker)

4. **Archive vs Delete goals**: Should completed goals be archived or deleted?
   - **Decision**: Mark as "completed" status, don't delete (preserve history)

---

## Ready to Implement?

Once you approve this plan, I will proceed with Phase 1 (Weekly Review) first, then Phase 2 (Goals).
