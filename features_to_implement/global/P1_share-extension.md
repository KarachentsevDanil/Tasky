# Share Extension for Task Capture

**Priority:** P1
**View Area:** global
**Status:** NOT_STARTED

## Problem
Users cannot create tasks from other apps. Reading an article, browsing a webpage, or viewing content requires copying text, switching to Tasky, pasting. Too much friction.

## Requirements

### Must Have
- [ ] Create Share Extension target
- [ ] Accept shared text - create task with text as title
- [ ] Accept shared URLs - create task with page title + URL in notes
- [ ] Accept shared images - create task with image reference (future: attachment)
- [ ] Minimal share sheet UI (title field, optional list picker, save button)
- [ ] Immediate save without opening main app
- [ ] Success haptic + dismissal

### Should Have
- [ ] AI parsing of shared text (extract task title from longer text)
- [ ] Date detection in shared text
- [ ] Default list configurable in settings
- [ ] "Open in Tasky" option for more details

## Components Affected

### Files to Create
- `TaskyShare/ShareViewController.swift` - Share extension entry
- `TaskyShare/ShareView.swift` - SwiftUI share interface
- `TaskyShare/ShareViewModel.swift` - Handle shared content

### Files to Modify
- `Tasky.xcodeproj` - Add Share Extension target
- `Services/CoreDataStack.swift` - App Group for shared container
- `Info.plist` (Share Extension) - Configure accepted types

## Key Notes
- Share Extension is separate process - minimal memory footprint
- Requires App Group for Core Data access
- Keep UI extremely simple - speed is the goal
- Handle all content types gracefully (text, URL, image)
- Consider character limits for task titles from long shared text
