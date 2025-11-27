# Bulk Operations

**Priority:** P2
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Cannot perform mass changes. "Push everything to next week", "make all work tasks high priority", "move today's incomplete to tomorrow" require tedious individual edits.

## Requirements

### Must Have
- [ ] Multi-select mode in task list (long press to enter)
- [ ] Selection indicators (checkmarks)
- [ ] Bulk complete (mark all selected done)
- [ ] Bulk delete (with confirmation)
- [ ] Bulk move to list
- [ ] Bulk reschedule (pick new date)
- [ ] Select all / deselect all
- [ ] Exit multi-select mode (done button or gesture)

### Should Have
- [ ] Bulk set priority
- [ ] Bulk add tag (when tags implemented)
- [ ] AI understands bulk commands ("move all overdue to tomorrow")
- [ ] Undo bulk operations
- [ ] Selection count indicator ("3 selected")

## Components Affected

### Files to Modify
- `Views/Tasks/TaskListView.swift` - Add multi-select mode state
- `Views/Tasks/TaskRowView.swift` - Selection checkbox state
- `ViewModels/TaskListViewModel.swift` - Bulk operation methods

### Files to Create
- `Views/Tasks/BulkActionBar.swift` - Floating action toolbar
- `Views/Tasks/BulkDatePickerSheet.swift` - Date selection for bulk reschedule
- `Views/Tasks/BulkListPickerSheet.swift` - List selection for bulk move

## Key Notes
- Clear visual feedback during multi-select (different row style)
- Confirmation required for destructive bulk actions (delete)
- Consider performance with 100+ selected tasks
- Haptic feedback on bulk action completion
- Undo should restore all affected tasks
