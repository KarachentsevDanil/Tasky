# Calendar Read Access

**Priority:** P0
**View Area:** global
**Status:** NOT_STARTED

## Problem
planDay AI tool generates useless schedules because it has no visibility into user's existing calendar events (meetings, appointments). Users get plans that conflict with their real commitments.

## Requirements

### Must Have
- [ ] Request EventKit calendar read permission with clear value explanation
- [ ] Fetch events from all user calendars for planning window (today + 7 days)
- [ ] Pass calendar events to planDay tool as blocked time slots
- [ ] Display external events in Calendar view (read-only, visually distinct)
- [ ] Handle permission denied gracefully (plan without calendar context)
- [ ] Respect user's calendar visibility preferences per-calendar

### Should Have
- [ ] Cache calendar events to reduce API calls
- [ ] Show calendar source indicator (iCloud, Google, etc.)
- [ ] Allow user to exclude specific calendars from planning context

## Components Affected

### Files to Modify
- `Info.plist` - Add NSCalendarsUsageDescription
- `Services/AI/Tools/PlanDayTool.swift` - Inject calendar context
- `Views/Calendar/CalendarDayView.swift` - Display external events
- `Views/Calendar/CalendarWeekView.swift` - Display external events

### Files to Create
- `Services/CalendarService.swift` - EventKit wrapper for fetching events
- `Models/ExternalEvent.swift` - Model for calendar events
- `Views/Calendar/ExternalEventView.swift` - Read-only event display component

## Key Notes
- EventKit requires specific privacy permission string
- Must handle case where user has no calendars configured
- External events should be visually distinct (grayed out, different style)
- This is a BLOCKER for useful AI planning - without it, planDay is decorative
- Consider background refresh for calendar updates
