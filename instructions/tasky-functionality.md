# Tasky - Complete Functionality Reference

> **Purpose**: Source document for AI-powered brainstorming of new features, improvements, and product direction.

---

## App Overview

**Tasky** is an iOS-native task manager combining simplicity with powerful AI capabilities. Built with SwiftUI and Core Data, it features on-device AI (Apple FoundationModels), focus timer with Live Activities, and a beautiful calendar-based time blocking system.

**Target Users**: iOS users who want a simple yet powerful personal task manager with AI assistance.

**Unique Differentiators**:
- AI-first natural language task management
- Voice-native task capture
- Integrated time blocking in calendar
- Focus timer with Dynamic Island support
- Beautiful iOS-native design

---

## Navigation Structure

### 5-Tab Layout
| Tab | Purpose | Primary Actions |
|-----|---------|-----------------|
| **Today** | Daily focus view | View/complete today's tasks |
| **Calendar** | Time blocking | Schedule tasks, view timeline |
| **AI Chat** | Natural language interface | Create/manage tasks via conversation |
| **Browse** | Navigation hub | Access lists, stats, settings |
| **(Lists)** | TBD | Future dedicated lists view |

---

## Core Features

### 1. Task Management

#### Task Properties
| Property | Description | Implementation |
|----------|-------------|----------------|
| Title | Task name (required) | Text field |
| Notes | Extended description | Expandable text area |
| Priority | 4 levels: None, Low, Medium, High | Visual picker |
| Due Date | When task is due | Date picker with presets |
| Scheduled Time | Time block start/end | 15-min increment picker |
| Duration | Estimated time to complete | Duration selector (1-180 min) |
| Custom List | Organizational grouping | List picker |
| Recurrence | Repeat pattern | Daily/Weekly selector |

#### Task Actions
- **Create**: Via Add button, Quick Add sheet, AI chat, or voice
- **Edit**: Full detail view with inline expandable sections
- **Complete**: Tap checkbox, swipe right, or AI command
- **Delete**: Swipe left with confirmation, or AI command
- **Reschedule**: Drag on calendar or edit time slot
- **Undo**: 5-second window for delete/complete actions

#### Task Grouping (Today View)
| Group | Description | Visual |
|-------|-------------|--------|
| Overdue | Past due, incomplete | Red badge |
| Now | Current time window | Blue highlight |
| Later Today | Scheduled for later | Orange indicator |
| Anytime | No specific time | Gray (neutral) |

---

### 2. Calendar & Time Blocking

#### Day View (Timeline)
- **Visual Timeline**: 6 AM - midnight, 60pt per hour
- **Current Time Indicator**: Red line showing "now"
- **Task Blocks**: Color-coded by list color
- **Auto-Scroll**: Opens at current time
- **Create Events**: Drag on empty space to create
- **Resize Events**: Drag bottom edge to adjust duration
- **Event Layout Engine**: Prevents overlaps, side-by-side positioning

#### Week View (Upcoming)
- Week calendar with day navigation
- Task list with due dates
- Mini calendar navigation
- Completed task filtering

#### Time Slot Picker
- **Increments**: 15-minute precision
- **Duration Presets**: 1m, 15m, 30m, 45m, 1h, 1.5h
- **Visual Grid**: Time blocks in accent color

---

### 3. AI Assistant (iOS 18.2+)

#### Chat Interface
- Message bubbles with typing indicators
- Suggestion chips for common actions
- Voice input support
- Session management (resets at ~3500 tokens)

#### AI Tools (Natural Language Commands)

| Tool | Function | Example |
|------|----------|---------|
| **CreateTasks** | Parse and create tasks | "Add buy groceries tomorrow at 2pm" |
| **CompleteTasks** | Mark tasks complete | "Complete all high priority tasks" |
| **UpdateTasks** | Modify task properties | "Change the meeting to 3pm" |
| **RescheduleTasks** | Move to new time | "Move report to next Monday" |
| **DeleteTasks** | Remove tasks | "Delete all completed tasks" |
| **PlanMyDay** | Generate daily schedule | "Plan my day" |
| **WeeklyReview** | Analyze productivity | "Show my weekly review" |
| **Cleanup** | Bulk operations | "Clean up old tasks" |

#### Task Filter System
- Filter by: list, status, priority, time range, keywords
- Pattern matching for task identification
- Bulk operations with undo support

---

### 4. Focus Timer (Pomodoro)

#### Timer Features
| Feature | Default | Customizable |
|---------|---------|--------------|
| Focus Duration | 25 min | Yes |
| Break Duration | 5 min | Yes |
| Target Sessions | 4/day | Yes |
| Warning Tones | 5 min, 1 min | Yes |

#### Timer States
- **Idle**: Ready to start
- **Running**: Countdown active
- **Paused**: Temporarily stopped
- **Completed**: Session finished

#### Live Activities & Dynamic Island
- Lock screen timer display
- Dynamic Island compact view
- Real-time updates (per second)
- Session progress indicator

#### Focus Streaks
- Daily streak counter
- Persists across app launches
- Resets after one day of inactivity
- Celebration animations for milestones

#### Focus Time Tracking
- Per-task focus time accumulation
- Total focus hours in statistics
- Session history in FocusSessionEntity

---

### 5. Task Lists

#### Custom Lists
- **Name**: User-defined
- **Color**: 8 options (Blue, Green, Orange, Red, Purple, Pink, Teal, Indigo)
- **Icon**: SF Symbol selection
- **Tasks**: Associated task relationship
- **Sort Order**: Customizable position

#### Smart Lists (Auto-Generated)
| List | Filter Logic | Icon |
|------|--------------|------|
| Today | Due today OR scheduled today | Calendar (blue) |
| Upcoming | Due within 7 days | Calendar badge clock (orange) |
| Inbox | No list assigned | Tray (gray) |
| Completed | isCompleted = true | Checkmark |

---

### 6. Progress & Analytics

#### Overview Tab Metrics
| Metric | Description |
|--------|-------------|
| Current Streak | Consecutive days with completions |
| Record Streak | All-time best streak |
| Tasks Completed | Total in selected period |
| Focus Hours | Total focus time |
| Completion Rate | Completed / Total percentage |
| Avg Tasks/Day | Daily average |

#### Visual Analytics
- Weekly activity bar chart
- Completion frequency heatmap
- Productivity score (0-100)
- Period comparison (vs previous week/month/year)

#### Patterns Tab
- Weekly activity analysis
- Peak productivity times
- Task completion patterns
- Focus time distribution
- List-specific metrics

#### Achievements (30+ Unlockable)

| Category | Examples |
|----------|----------|
| **Streaks** | Week Warrior (7 days), Diamond (30 days) |
| **Speed** | Speed Demon (10/day), Champion (100 total) |
| **Volume** | Task Master (500), Productivity Legend (1000) |
| **Focus** | Focus Ninja, Flow State Master |
| **Consistency** | Iron Habit, Perfect Week |
| **Lists** | Organizer, Multi-tasker |
| **Time-based** | Early Bird, Night Owl |

---

### 7. Voice Input

#### Speech Recognition
- Real-time transcription
- English (US) locale
- Microphone permission handling
- Error state management

#### Integration Points
- AI Chat voice input
- Quick Add sheet
- Natural language parsing

---

### 8. Notifications

#### Notification Types
| Type | Trigger |
|------|---------|
| Task Due | When due date arrives |
| Scheduled Time | 15 min before scheduled time |
| Advance Reminder | 15 min before any deadline |
| Timer Complete | Focus session ends |

#### Interactive Actions
- **Complete**: Mark task done from notification
- **Snooze**: Delay by 15 minutes
- **Start Focus**: Open timer for task

---

### 9. Settings

#### Appearance
- Theme: System / Light / Dark
- Segmented control UI

#### Notifications
- Master toggle
- Per-type toggles (due, scheduled, advance, timer)
- Authorization status display

#### Haptics
- Enable/disable haptic feedback

#### Advanced
- Export data (CSV)
- AI task preview toggle

---

## Technical Infrastructure

### Data Model (Core Data)

#### TaskEntity
```
- id, title, notes
- isCompleted, dueDate, scheduledTime, scheduledEndTime
- createdAt, completedAt
- priority (0-3), priorityOrder
- focusTimeSeconds, aiPriorityScore
- estimatedDuration (minutes)
- isRecurring, recurrenceDays
- taskList (relationship)
- focusSessions (relationship)
```

#### TaskListEntity
```
- id, name, colorHex, iconName
- createdAt, sortOrder
- tasks (relationship)
```

#### FocusSessionEntity
```
- id, startTime, duration (seconds)
- completed (Bool)
- task (relationship)
```

### AI Priority Scoring
Tasks are auto-scored based on:
- Due date proximity
- Priority level
- Task age (staleness)
- Completion history

Used for intelligent sorting in All Tasks view.

---

## UX Patterns

### Haptic Feedback
| Action | Haptic Type |
|--------|-------------|
| Task completion | .success |
| Button tap | .lightImpact |
| Picker change | .selectionChanged |

### Animations
- Spring animations (response: 0.35, damping: 0.8)
- Expand/collapse for form sections
- Confetti for celebrations
- Reduced motion support

### Visual Feedback
- Completion ring for daily progress
- Confetti on all tasks completed
- Achievement unlock celebrations
- Undo toast (5-second window)

### Form Design (Things 3-Inspired)
- Inline expandable sections (no modal stacking)
- Progressive disclosure
- Quick actions for common choices
- Visual hierarchy with icons and colors

---

## Implementation Status

### Fully Complete
- Today tab with task grouping
- Calendar day view with timeline
- AI Assistant with tool calling
- Browse tab navigation hub
- Task creation/editing
- Focus timer with Live Activities
- Progress analytics & achievements
- Custom task lists
- Voice input
- Notifications
- Undo system
- Settings
- Haptics & animations
- Accessibility basics

### Partial / In Progress
- Calendar week view (basic, not full month)
- Task widgets (infrastructure ready)

### Infrastructure Ready (Not Yet UI)
- None currently - all major features implemented

---

## Platform Requirements

| Feature | Minimum iOS |
|---------|-------------|
| Core app | iOS 16.0 |
| Live Activities | iOS 16.2 |
| AI Assistant | iOS 18.2 (FoundationModels) |

---

## Key Differentiators from Competitors

| vs Things 3 | vs Todoist | vs Apple Reminders |
|-------------|------------|-------------------|
| AI-powered | iOS-native | Advanced features |
| Focus timer | Simpler UI | AI assistant |
| Free tier | No complexity | Time blocking |
| Voice-first | Beautiful design | Focus timer |

---

## Future Consideration Areas

Based on current implementation, these areas have no infrastructure:
- Subtasks/checklists
- Tags/labels system
- Attachments (notes, files, images)
- Collaboration/sharing
- Home screen widgets
- Search functionality
- Siri Shortcuts
- Task templates
- Habits tracking
- External calendar sync
- Batch operations UI
- Apple Watch app

---

*Last updated: November 2024*
*Use this document as context for product brainstorming sessions.*
