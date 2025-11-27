# Apple Watch App

**Priority:** P2
**View Area:** global
**Status:** NOT_STARTED

## Problem
Fastest task capture requires pulling out phone. Watch enables 2-second voice capture from wrist. Competitors (Todoist, Things) have watch apps that increase engagement.

## Requirements

### Must Have
- [ ] Create watchOS app target
- [ ] Today's tasks list view
- [ ] Mark task complete with tap
- [ ] Voice capture via dictation → create task
- [ ] Sync with phone via Watch Connectivity
- [ ] Complication: next task

### Should Have
- [ ] Complication: task count for today
- [ ] Complication: focus timer (when implemented)
- [ ] Haptic reminder for scheduled tasks
- [ ] Quick reply to task ("Done", "Snooze")

## Components Affected

### Files to Create
- `TaskyWatch/TaskyWatchApp.swift` - watchOS app entry point
- `TaskyWatch/ContentView.swift` - Main watch interface
- `TaskyWatch/TaskRowView.swift` - Task display for watch
- `TaskyWatch/ComplicationViews.swift` - Complication templates
- `Shared/WatchConnectivityManager.swift` - Phone-watch sync

### Files to Modify
- `Tasky.xcodeproj` - Add watchOS target
- `TaskyApp.swift` - Initialize Watch Connectivity on phone side

## Key Notes
- watchOS has severe memory/performance constraints
- Use Watch Connectivity for sync, not shared Core Data
- Complications drive watch app engagement
- Voice capture is the killer feature for watch
- Keep UI minimal - small screen, quick glances only
