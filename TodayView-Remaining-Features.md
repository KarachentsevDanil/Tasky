# Today View - Remaining Features & Improvements

## Overview
This document outlines features and improvements that could be implemented for the Today view to further enhance user experience and productivity.

---

## High Priority Features

### 1. Time-Based Task Ordering & Visual Grouping
**Status:** Not Implemented
**RICE Score:** 8.4
**Effort:** 1 week

**Description:**
Automatically group and order tasks based on their scheduled time and status.

**Implementation Details:**
- Group tasks into time-based sections:
  - **Overdue** (red tint) - Past due date/time
  - **Now** (highlight) - Scheduled within next 2 hours
  - **Later Today** - Scheduled later
  - **No Time** - Bottom of list
- Add visual separators between groups
- Add "Now" indicator line showing current time
- Within each group, sort by priority then alphabetically

**Files to Modify:**
- `TaskListViewModel.swift` - Update sorting logic in `todayTasks` computed property
- `TodayView.swift` - Add section headers and separators

**User Value:**
Users can quickly see what needs immediate attention vs. what can wait, reducing decision fatigue.

---

### 2. Enhanced Empty State
**Status:** Basic implementation exists
**RICE Score:** 6.0
**Effort:** 3 days

**Description:**
Replace current basic empty state with engaging, helpful design.

**Current State:**
- Shows generic "No tasks" message via `EmptyStateView.noTasks()`

**Proposed Design:**
```
┌──────────────────────────────┐
│                              │
│         ✨ 🎯 ✨            │
│                              │
│   All caught up!             │
│   What's your next goal?     │
│                              │
│   Quick suggestions:         │
│   • Start with "Call..."     │
│   • Try "tomorrow at 3pm"    │
│   • Use !high for priority   │
│                              │
│   [Tap + to create task]     │
│                              │
└──────────────────────────────┘
```

**Implementation Details:**
- Animated checkmark icon with subtle pulse
- Contextual tips about natural language features
- Different states:
  - First-time user: Onboarding tips
  - Returning user: Motivational message
  - Power user: Quick action shortcuts

**Files to Create:**
- `Views/Components/TodayEmptyStateView.swift`

**Files to Modify:**
- `TodayView.swift` - Replace `EmptyStateView.noTasks()` call

---

### 3. Multi-Modal Quick Add Bar
**Status:** Partially Implemented (NLP exists, but no visible mode switcher)
**RICE Score:** 7.5
**Effort:** 1.5 weeks

**Description:**
Make voice and AI modes more discoverable by showing buttons in the quick add bar.

**Current State:**
- Natural language parsing works inline
- Voice and AI features exist but require navigating to separate tabs

**Proposed Design:**
```
┌─────────────────────────────────────────┐
│ [+]  Task name...  [🎤] [✨] [•••]     │
└─────────────────────────────────────────┘
         ↓ (when focused/active)
┌─────────────────────────────────────────┐
│ [Type]  [🎤 Voice]  [✨ AI]             │
│ ─────────────────────────────────────── │
│ [Task input with suggestions]           │
└─────────────────────────────────────────┘
```

**Implementation Details:**
- Add mode selector buttons that appear on focus
- Integrate `VoiceInputManager` directly into quick add
- Show "AI Coach" sheet overlay when AI button tapped
- Smooth transitions between modes
- Remember user's preferred mode

**Files to Modify:**
- `QuickAddCardView.swift` - Add mode buttons and voice integration
- `TodayView.swift` - Add state for voice recording and AI sheet

**User Value:**
Reduces friction to use advanced features - users don't need to know about separate tabs.

---

## Medium Priority Features

### 4. Enhanced Completion Celebration
**Status:** Basic implementation (confetti + haptics)
**RICE Score:** 4.8
**Effort:** 1 week

**Description:**
More engaging celebration when completing tasks, especially when clearing all tasks.

**Current State:**
- Confetti animation on task completion
- Success haptic feedback
- Completed task auto-collapses

**Proposed Enhancements:**

**Single Task Completion:**
- ✅ Current: Confetti + haptic (good)
- Add: Checkmark scale animation with bounce
- Add: Brief green highlight pulse

**All Tasks Completed:**
- Full-screen confetti burst
- Completion ring animation (similar to Progress tab)
- Encouraging message: "All done! 🎉 Time to relax"
- Optional: Streak counter if completed daily goals X days in a row
- Optional: Share achievement button

**Implementation Details:**
- Detect when last active task is completed
- Show full-screen celebration overlay
- Auto-dismiss after 2 seconds or on tap
- Track streaks in UserDefaults or Core Data

**Files to Create:**
- `Views/Components/AllDoneCelebrationView.swift`

**Files to Modify:**
- `TodayView.swift` - Add celebration logic to `toggleTaskCompletion()`

---

### 5. Drag-to-Reorder Tasks
**Status:** Infrastructure exists (`priorityOrder` field), UI not implemented
**RICE Score:** 5.6
**Effort:** 1 week

**Description:**
Allow users to manually reorder tasks by dragging.

**Current State:**
- `TaskEntity` has `priorityOrder` field
- `DataService` has `reorderTasks()` method
- No UI for reordering

**Implementation Details:**
- Add `.onMove` modifier to ForEach in `tasksSection`
- Update `priorityOrder` on drag
- Animate reordering smoothly
- Add haptic feedback during drag
- Temporarily disable auto-sorting while user manually reorders
- Add "Reset to auto-sort" button in context menu

**Files to Modify:**
- `TodayView.swift` - Add drag gesture handling
- `TaskListViewModel.swift` - Add manual sort mode flag

**User Value:**
Power users can customize task order for their workflow, overriding automatic sorting.

---

### 6. Quick Filter Chips
**Status:** Not Implemented
**RICE Score:** 4.5
**Effort:** 3 days

**Description:**
Add filter chips above task list for quick filtering.

**Proposed Design:**
```
┌─────────────────────────────────────────┐
│ Quick Add Card                          │
├─────────────────────────────────────────┤
│ [All] [High Priority] [Scheduled] [•••] │
├─────────────────────────────────────────┤
│ Task List...                            │
└─────────────────────────────────────────┘
```

**Filter Options:**
- All (default)
- High Priority (priority >= 2)
- Scheduled (has scheduled time)
- Overdue (past due date)
- Custom (user-created filters)

**Implementation Details:**
- Add filter state in `TodayView`
- Filter `todayTasks` based on selected chip
- Smooth animation when switching filters
- Persist last-used filter

**Files to Create:**
- `Views/Components/FilterChipBar.swift`

**Files to Modify:**
- `TodayView.swift` - Integrate filter bar and logic

---

## Low Priority / Nice-to-Have

### 7. Keyboard Shortcuts (iPad/Mac)
**Status:** Not Implemented
**RICE Score:** 2.0
**Effort:** 1 week

**Description:**
Add keyboard shortcuts for power users on iPad with keyboard or Mac.

**Proposed Shortcuts:**
- `⌘N` - Focus quick add input
- `⌘Return` - Submit task
- `Esc` - Cancel/blur input
- `⌘1-4` - Set priority (none/low/medium/high)
- `⌘D` - Toggle task done (when task selected)
- `⌘Delete` - Delete task (when task selected)
- `⌘,` - Open settings

**Implementation Details:**
- Add `.keyboardShortcut()` modifiers
- Show shortcuts in context menu hints
- Add to help/documentation
- Test on iPad with external keyboard

**Files to Modify:**
- `TodayView.swift` - Add keyboard shortcuts
- Create keyboard shortcut documentation

---

### 8. Batch Operations
**Status:** Not Implemented
**RICE Score:** 2.5
**Effort:** 2 weeks

**Description:**
Select multiple tasks and perform bulk actions.

**Proposed UI:**
- Long press on task → Enter selection mode
- Checkboxes appear on left of tasks
- Floating action bar at bottom with actions:
  - Complete all
  - Delete all
  - Reschedule all
  - Change priority
  - Move to list

**Implementation Details:**
- Add selection mode state
- Track selected task IDs
- Implement bulk operations in `DataService`
- Add undo support for batch operations
- Haptic feedback on selection

**Files to Create:**
- `Views/Components/BatchActionBar.swift`

**Files to Modify:**
- `TodayView.swift` - Add selection mode
- `TaskListViewModel.swift` - Add batch operation methods

---

### 9. Smart Suggestions
**Status:** Not Implemented
**RICE Score:** 3.0
**Effort:** 2 weeks

**Description:**
Proactive suggestions based on user patterns.

**Suggested Features:**
- "You usually call mom on Fridays. Add now?"
- "Recurring task pattern detected. Make it repeat?"
- "You have 3 tasks scheduled at 2pm. Want to spread them out?"
- "High priority task overdue for 3 days. Reschedule or delete?"

**Implementation Details:**
- Analyze task patterns in background
- Show non-intrusive suggestion cards
- Easy to dismiss or accept
- Learn from user responses

**Technical Complexity:**
- Pattern detection algorithms
- Privacy considerations (on-device only)
- Performance impact of analysis

---

### 10. Widget Integration
**Status:** Not Implemented
**RICE Score:** 6.5
**Effort:** 2-3 weeks

**Description:**
Home screen and Lock Screen widgets showing today's tasks.

**Widget Types:**

**Small Widget:**
- Task count: "5 tasks today"
- Next scheduled task time
- Tap to open app

**Medium Widget:**
- List of next 3-4 tasks
- Completion checkboxes (interactive)
- Tap task to open detail

**Large Widget:**
- Full task list (scrollable)
- Add task button
- Completion ring

**Lock Screen Widget:**
- Next task name + time
- Task count

**Implementation Details:**
- Create `WidgetExtension` target
- Use WidgetKit framework
- Share Core Data with widget
- Handle interactive elements
- Support dark mode and tinting

**Files to Create:**
- `WidgetExtension/` folder with widget views

---

## Technical Debt & Polish

### Performance Optimizations
- [ ] Profile with Instruments on large task lists (1000+ tasks)
- [ ] Lazy load completed tasks (don't render until expanded)
- [ ] Debounce NLP parsing (currently runs on every keystroke)
- [ ] Cache parsed results to avoid re-parsing

### Accessibility Improvements
- [ ] Test with VoiceOver at all sizes
- [ ] Verify all dynamic font sizes work
- [ ] Add more descriptive accessibility hints
- [ ] Test with Voice Control
- [ ] Ensure all animations respect Reduce Motion

### Animation Polish
- [ ] Add micro-interactions to checkboxes (scale + rotate)
- [ ] Smooth entrance animations for new tasks
- [ ] Exit animations when tasks deleted
- [ ] Parallax effect on scroll (subtle)

### Error Handling
- [ ] Graceful handling when Core Data save fails
- [ ] Retry logic for failed operations
- [ ] User-friendly error messages
- [ ] Offline mode indicators

---

## Feature Comparison with Competitors

| Feature | Tasky (Current) | Things 3 | Todoist | Apple Reminders |
|---------|----------------|----------|---------|-----------------|
| Natural Language | ✅ Inline | ✅ | ✅ | ✅ |
| Voice Input | ✅ Separate tab | ❌ | ❌ | ✅ (Siri) |
| Swipe Actions | ✅ | ✅ | ✅ | ✅ |
| Drag Reorder | ❌ | ✅ | ✅ | ✅ |
| Time Grouping | ❌ | ✅ | ✅ | ✅ |
| Batch Operations | ❌ | ✅ | ✅ | ❌ |
| Widgets | ❌ | ✅ | ✅ | ✅ |
| Keyboard Shortcuts | ❌ | ✅ | ✅ | ❌ |

---

## Implementation Priority Order

**Sprint 1 (2 weeks):**
1. Time-based ordering (#1)
2. Enhanced empty state (#2)

**Sprint 2 (2 weeks):**
3. Multi-modal quick add (#3)
4. Enhanced celebrations (#4)

**Sprint 3 (2 weeks):**
5. Drag-to-reorder (#5)
6. Quick filter chips (#6)

**Later (Backlog):**
7. Widget integration (#10) - High business value
8. Batch operations (#8)
9. Smart suggestions (#9)
10. Keyboard shortcuts (#7)

---

## Success Metrics

Track these analytics to measure impact:

**Engagement:**
- Tasks created per session (target: +20%)
- Time to create task (target: <5 seconds)
- Feature adoption rates (swipe, voice, NLP)

**Retention:**
- Daily active users (target: 60% of sign-ups)
- 7-day retention (target: 40%)
- 30-day retention (target: 25%)

**Productivity:**
- Task completion rate (target: 70%)
- Tasks completed per day (target: 8-10)
- Overdue task rate (target: <20%)

**Feature-Specific:**
- Natural language usage (% of tasks)
- Voice input adoption (% of users)
- Swipe gesture usage (vs. tap checkbox)
- Context menu discovery (% of users)

---

## Notes

- All features should maintain the app's core philosophy: **simple, delightful, native**
- Each feature must pass the RICE score threshold (>0.8)
- Always implement with accessibility in mind
- Follow iOS HIG patterns strictly
- Write code that's maintainable and well-documented

---

**Last Updated:** November 14, 2025
**Version:** 1.0
**Status:** Active Development
