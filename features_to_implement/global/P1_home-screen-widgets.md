# Home Screen Widgets

**Priority:** P1
**View Area:** global
**Status:** NOT_STARTED

## Problem
Tasky has zero home screen presence. Users must open app to see tasks. Competing apps (Reminders, Things) have widgets that keep tasks visible and reduce friction.

## Requirements

### Must Have
- [ ] Create Widget Extension target
- [ ] "Today Tasks" widget (small/medium) - show today's tasks with completion status
- [ ] "Next Task" widget (small) - single most important task
- [ ] Tap widget opens app to relevant view
- [ ] Tap task in widget marks complete (iOS 17+ interactive)
- [ ] Widgets update when tasks change (Timeline refresh)
- [ ] Support light/dark mode
- [ ] Support Dynamic Type in widgets

### Should Have
- [ ] "Quick Add" widget (medium) - tap to open quick add sheet
- [ ] "Focus Timer" widget (small) - show active session or start button
- [ ] "Progress Ring" widget (small) - daily completion percentage
- [ ] Widget configuration (which list to show)
- [ ] Lock screen widgets (iOS 16+)

## Components Affected

### Files to Create
- `TaskyWidget/TaskyWidget.swift` - Widget extension entry point
- `TaskyWidget/TodayTasksWidget.swift` - Today's tasks widget
- `TaskyWidget/NextTaskWidget.swift` - Single task widget
- `TaskyWidget/WidgetTaskProvider.swift` - Timeline provider
- `Shared/TaskyShared.swift` - Shared models between app and widget

### Files to Modify
- `Tasky.xcodeproj` - Add Widget Extension target
- `Services/CoreDataStack.swift` - App Group for shared container

## Key Notes
- Requires App Group for Core Data sharing between app and widget
- Widget Extension has separate binary - keep dependencies minimal
- Timeline provider determines refresh frequency (balance freshness vs battery)
- Interactive widgets (iOS 17+) need App Intent for completion action
- Test widgets at all sizes and with Dynamic Type
