# Morning Brief

**Priority:** P2
**View Area:** today_view
**Status:** NOT_STARTED

## Problem
Users open app to a raw task list each morning. No guidance on what matters most. The AI planning exists but requires manual invocation. Should proactively help users start their day.

## Requirements

### Must Have
- [ ] Morning notification with brief summary (configurable time)
- [ ] Notification shows: task count, top priority task
- [ ] Tap notification opens dedicated Morning Brief view
- [ ] Brief view shows: top 3 focus tasks, overdue count, schedule overview
- [ ] "Start my day" action that marks brief as reviewed
- [ ] Skip brief option
- [ ] Configurable brief time in settings (default 7:00 AM)

### Should Have
- [ ] Context-aware: "You have 2 meetings today" (requires calendar integration)
- [ ] Weather context: "Nice day - maybe outdoor errands?"
- [ ] Goal reminder: "You wanted to work on [goal] this week"
- [ ] Motivational framing from AI
- [ ] Brief customization (what to include)
- [ ] Weekend vs weekday different times

## Brief Content Structure

| Section | Content |
|---------|---------|
| Header | "Good morning! Here's your day" |
| Focus Tasks | Top 3 priority tasks for today |
| Overdue Alert | "3 tasks overdue" (if any) |
| Schedule | Timeline preview (if calendar integrated) |
| Goal Nudge | Reminder about active goal (if neglected) |
| Action | "Start my day" button |

## Components Affected

### Files to Create
- `Views/Today/MorningBriefView.swift` - Brief presentation view
- `ViewModels/MorningBriefViewModel.swift` - Brief data assembly
- `Services/MorningBriefService.swift` - Notification scheduling, brief generation

### Files to Modify
- `Services/NotificationService.swift` - Schedule morning notification
- `Views/Settings/NotificationSettingsView.swift` - Brief time configuration
- `TaskyApp.swift` - Handle notification tap to open brief

## Key Notes
- Default time: 7:00 AM (configurable in settings)
- Brief should be glanceable (30 seconds max to review)
- Don't overwhelm - focus on TOP priorities only
- Requires calendar access for meeting awareness (P0 dependency)
- Consider: should brief auto-show on first app open of day?
