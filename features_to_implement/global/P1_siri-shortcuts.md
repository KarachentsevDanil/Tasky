# Siri Shortcuts Integration

**Priority:** P1
**View Area:** global
**Status:** NOT_STARTED

## Problem
Users cannot capture tasks via voice without opening app. "Hey Siri, remind me to..." goes to Apple Reminders. Tasky misses the fastest capture method available on iOS.

## Requirements

### Must Have
- [ ] Create App Intents for core actions
- [ ] "Add Task" intent - create task with title, optional date/list
- [ ] "Show Today's Tasks" intent - open app to Today view
- [ ] "Complete Task" intent - mark task done by name
- [ ] Donate intents for Siri suggestions
- [ ] Support Shortcuts app integration
- [ ] Voice input triggers AI parsing for natural language

### Should Have
- [ ] "Start Focus Session" intent - begin Pomodoro timer
- [ ] "What's Next" intent - Siri reads top priority task
- [ ] "Plan My Day" intent - trigger AI planning, read summary
- [ ] Parameterized shortcuts (user can customize)
- [ ] Siri Suggestions based on usage patterns

## Components Affected

### Files to Create
- `Intents/AddTaskIntent.swift` - Add task App Intent
- `Intents/ShowTodayIntent.swift` - Open Today view intent
- `Intents/CompleteTaskIntent.swift` - Complete task intent
- `Intents/TaskyShortcuts.swift` - Shortcuts provider
- `Intents/IntentHandler.swift` - Intent handling logic

### Files to Modify
- `Info.plist` - Register App Intents
- `TaskyApp.swift` - Handle intent launches
- `Services/TaskService.swift` - Add methods for intent operations

## Key Notes
- Use App Intents framework (iOS 16+), not legacy SiriKit
- Intents should work even when app is not running
- Donate intents after user actions for better Siri suggestions
- Voice input should leverage existing AI parsing infrastructure
- Test with various Siri phrasings
