# Spotlight Search Integration

**Priority:** P3
**View Area:** global
**Status:** NOT_STARTED

## Problem
Tasks are not searchable via iOS Spotlight. Users cannot find tasks without opening the app first.

## Requirements

### Must Have
- [ ] Index tasks in Core Spotlight (CSSearchableIndex)
- [ ] Search by task title
- [ ] Tap result opens task detail view
- [ ] Update index when tasks change (create, edit, delete, complete)
- [ ] Remove completed tasks from index (optional setting)

### Should Have
- [ ] Rich result preview (title, due date, list)
- [ ] Siri suggestions based on usage patterns
- [ ] Search by list name
- [ ] Index task notes content

## Indexed Attributes

| Attribute | Spotlight Field | Searchable |
|-----------|-----------------|------------|
| title | title | Yes |
| notes | contentDescription | Yes |
| dueDate | - | No (display only) |
| listName | - | No (display only) |
| priority | - | No (display only) |

## Components Affected

### Files to Create
- `Services/SpotlightService.swift` - Index management, search handling

### Files to Modify
- `Services/TaskService.swift` - Trigger index updates on CRUD
- `TaskyApp.swift` - Handle Spotlight result tap (continue user activity)
- `Info.plist` - Configure NSUserActivityTypes

## Key Notes
- Use CSSearchableItem for indexing
- Set appropriate expirationDate for items
- Handle NSUserActivity for result taps
- Consider indexing batch for performance
- Re-index on app update if schema changes
