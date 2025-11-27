# Focus Modes Integration

**Priority:** P3
**View Area:** global
**Status:** NOT_STARTED

## Problem
iOS Focus modes (Work, Personal, Sleep) aren't reflected in Tasky. User must manually switch context between work and personal task views.

## Requirements

### Must Have
- [ ] Detect active iOS Focus mode
- [ ] Auto-filter task list by Focus-associated lists
- [ ] Respect Focus notification filtering settings
- [ ] Graceful fallback when no Focus active (show all)

### Should Have
- [ ] Configure which lists show per Focus mode in settings
- [ ] Focus-aware widgets (show relevant tasks only)
- [ ] Focus mode indicator in app UI
- [ ] Different default list per Focus mode

## Focus Mode Mapping

| Focus Mode | Default Lists | Behavior |
|------------|---------------|----------|
| Work | Work, Projects | Hide Personal, Family |
| Personal | Personal, Family, Shopping | Hide Work |
| Sleep | None | Suppress all notifications |
| Fitness | Health, Exercise | Show relevant only |
| Custom | User configured | As specified |

## Components Affected

### Files to Create
- `Services/FocusModeService.swift` - Detect active Focus, manage mappings
- `Views/Settings/FocusModeSettingsView.swift` - Configure list mappings

### Files to Modify
- `Views/Tasks/TaskListView.swift` - Apply Focus filter
- `Services/NotificationService.swift` - Respect Focus settings
- `TaskyWidget/` - Focus-aware widget content

## Key Notes
- Uses INFocusStatusCenter API (iOS 15+)
- Requires Focus Status entitlement
- User must grant Focus access permission
- Should enhance, not require - works without Focus access too
