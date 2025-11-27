# Global Features Implementation Plan

## Overview

This plan implements P0 and P1 priority features from the `features_to_implement/global` folder:

| Priority | Feature | Complexity | Estimated Files |
|----------|---------|------------|-----------------|
| P0 | Calendar Read Access | Medium | 6 new, 4 modified |
| P1 | Home Screen Widgets | High | 8 new, 2 modified |
| P1 | Share Extension | Medium | 5 new, 2 modified |
| P1 | Siri Shortcuts | Medium | 6 new, 2 modified |

---

## Phase 1: P0 - Calendar Read Access (Foundation)

### 1.1 Create CalendarService

**File:** `Tasky/Core/Services/CalendarService.swift`

```swift
// EventKit wrapper that handles:
// - Permission request with clear value explanation
// - Fetch events from all user calendars
// - Cache events for 15 minutes
// - Support calendar visibility preferences
// - Return ExternalEvent models (not EKEvent directly)
```

**Key Methods:**
- `requestAccess() async -> Bool`
- `fetchEvents(from:to:) async throws -> [ExternalEvent]`
- `fetchEventsForDay(_ date: Date) async throws -> [ExternalEvent]`
- `getAvailableCalendars() -> [CalendarInfo]`
- `setCalendarEnabled(_ identifier: String, enabled: Bool)`

### 1.2 Create ExternalEvent Model

**File:** `Tasky/Core/Models/ExternalEvent.swift`

```swift
struct ExternalEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColor: Color
    let location: String?
    let notes: String?
}

struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: Color
    let source: String  // iCloud, Google, Exchange
    var isEnabled: Bool
}
```

### 1.3 Update Info.plist

**File:** `Tasky/Info.plist` (add key)

```xml
<key>NSCalendarsUsageDescription</key>
<string>Tasky uses your calendar to show existing events and avoid scheduling conflicts when planning your day.</string>
```

### 1.4 Integrate with PlanDayTool

**File:** `Tasky/Features/AIChat/Tools/PlanDayTool.swift` (modify)

Add calendar context injection:
- Fetch external events for the target date
- Calculate blocked time slots from events
- Pass blocked slots to planning logic
- Reduce available hours based on calendar events
- Include event summary in response

### 1.5 Create ExternalEventView Component

**File:** `Tasky/Features/Calendar/Views/Components/ExternalEventView.swift`

```swift
// Read-only event display with:
// - Grayed out/semi-transparent appearance
// - Calendar source indicator
// - Proper accessibility labels
// - Collision layout support (uses EventLayoutEngine)
```

### 1.6 Update DayCalendarView

**File:** `Tasky/Features/Calendar/Views/Screens/DayCalendarView.swift` (modify)

- Add `@State private var externalEvents: [ExternalEvent] = []`
- Load external events in `.task` modifier
- Render ExternalEventView alongside CalendarEventView
- Support mixed layout with EventLayoutEngine

### 1.7 Update DayCalendarViewModel

**File:** `Tasky/Features/Calendar/ViewModels/DayCalendarViewModel.swift` (modify)

- Add CalendarService dependency
- Add `externalEvents: [ExternalEvent]` property
- Update `layoutEvents()` to include external events
- Handle permission states

### 1.8 Calendar Settings (Optional Enhancement)

**File:** `Tasky/Features/Settings/Views/Components/CalendarSettingsView.swift`

- Toggle for calendar integration
- List of available calendars with enable/disable
- Visual preview of calendar colors

---

## Phase 2: P1 - Home Screen Widgets

### 2.1 Set Up App Groups

**Xcode Project Changes:**
1. Add App Group capability to main app target
2. Add App Group capability to TaskyWidgets target
3. Use identifier: `group.LaktionovaSoftware.Tasky`

### 2.2 Create Shared Data Container

**File:** `Shared/SharedPersistenceController.swift`

```swift
// Shared Core Data stack that:
// - Uses App Group container URL
// - Provides read-only access for widgets
// - Handles migration from old store location
```

### 2.3 Create Shared Task Model

**File:** `Shared/WidgetTask.swift`

```swift
// Lightweight struct for widget display:
struct WidgetTask: Identifiable, Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: Int
    let listName: String?
    let listColor: String?
}
```

### 2.4 Create Widget Data Provider

**File:** `TaskyWidgets/Providers/TaskWidgetProvider.swift`

```swift
// TimelineProvider implementation:
// - Fetch today's tasks from shared container
// - Create timeline entries
// - Refresh policy: .after(15 minutes)
```

### 2.5 Create TodayTasksWidget

**File:** `TaskyWidgets/Widgets/TodayTasksWidget.swift`

```swift
// Supports: small, medium sizes
// Shows:
// - Date header
// - List of today's incomplete tasks (3-5 depending on size)
// - Completion percentage ring
// - Tap opens app to Today view
```

### 2.6 Create NextTaskWidget

**File:** `TaskyWidgets/Widgets/NextTaskWidget.swift`

```swift
// Supports: small size only
// Shows:
// - Single most important task (by aiPriorityScore)
// - Due date/time if set
// - Priority indicator
// - Tap opens app to task detail
```

### 2.7 Add Interactive Completion (iOS 17+)

**File:** `TaskyWidgets/Intents/CompleteTaskIntent.swift`

```swift
// AppIntent for completing tasks from widget:
// - Parameter: task ID
// - Updates Core Data
// - Reloads timeline
```

### 2.8 Update Widget Bundle

**File:** `TaskyWidgets/TaskyWidgetsBundle.swift` (modify)

```swift
@main
struct TaskyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusTimerLiveActivity()  // Existing
        TodayTasksWidget()        // New
        NextTaskWidget()          // New
    }
}
```

### 2.9 Update PersistenceController for App Groups

**File:** `Tasky/Core/Services/PersistenceController.swift` (modify)

- Update store URL to use App Group container
- Handle one-time migration from old location

---

## Phase 3: P1 - Share Extension

### 3.1 Create Share Extension Target

**Xcode Project:**
1. File > New > Target > Share Extension
2. Name: `TaskyShare`
3. Bundle ID: `LaktionovaSoftware.Tasky.TaskyShare`
4. Add App Group capability

### 3.2 Configure Share Extension Info.plist

**File:** `TaskyShare/Info.plist`

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

### 3.3 Create ShareViewController

**File:** `TaskyShare/ShareViewController.swift`

```swift
// UIViewController that hosts SwiftUI view
// - Extracts shared content from extensionContext
// - Handles text, URL content types
// - Presents ShareView in UIHostingController
```

### 3.4 Create ShareView

**File:** `TaskyShare/ShareView.swift`

```swift
// Minimal SwiftUI interface:
// - Title TextField (pre-filled from shared content)
// - Optional list picker (defaults to Inbox)
// - Save button with haptic feedback
// - Cancel button
// - Loading state during save
```

### 3.5 Create ShareDataService

**File:** `TaskyShare/ShareDataService.swift`

```swift
// Lightweight service for extension:
// - Uses shared App Group container
// - Creates task with minimal dependencies
// - No notification scheduling (main app handles)
```

---

## Phase 4: P1 - Siri Shortcuts

### 4.1 Create AddTaskIntent

**File:** `Tasky/Intents/AddTaskIntent.swift`

```swift
@available(iOS 16.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Create a new task in Tasky")

    @Parameter(title: "Task Title")
    var title: String

    @Parameter(title: "Due Date", default: nil)
    var dueDate: Date?

    @Parameter(title: "List", default: nil)
    var list: String?

    func perform() async throws -> some IntentResult {
        // Create task using DataService
        // Return spoken confirmation
    }
}
```

### 4.2 Create ShowTodayIntent

**File:** `Tasky/Intents/ShowTodayIntent.swift`

```swift
struct ShowTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Today's Tasks"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Opens app to Today view
    }
}
```

### 4.3 Create CompleteTaskIntent

**File:** `Tasky/Intents/CompleteTaskIntent.swift`

```swift
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task Name")
    var taskName: String

    func perform() async throws -> some IntentResult {
        // Find task by fuzzy match
        // Mark as complete
        // Return spoken confirmation
    }
}
```

### 4.4 Create TaskyShortcuts Provider

**File:** `Tasky/Intents/TaskyShortcuts.swift`

```swift
struct TaskyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Create task in \(.applicationName)",
                "Add to my \(.applicationName) list"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        // ... more shortcuts
    }
}
```

### 4.5 Register Intents in App

**File:** `Tasky/TaskyApp.swift` (modify)

```swift
@main
struct TaskyApp: App {
    // Add intent donation on relevant actions
    // Handle app launch from intents
}
```

### 4.6 Donate Intents for Siri Suggestions

**File:** `Tasky/Intents/IntentDonation.swift`

```swift
// Helper to donate intents after user actions:
// - After creating a task
// - After completing a task
// - After opening Today view
```

---

## Implementation Order

### Day 1: Foundation
1. CalendarService.swift
2. ExternalEvent.swift
3. Info.plist calendar permission

### Day 2: Calendar Integration
4. Update PlanDayTool with calendar context
5. ExternalEventView component
6. Update DayCalendarView/ViewModel

### Day 3: App Groups & Shared Data
7. Set up App Groups in Xcode
8. SharedPersistenceController
9. Update main PersistenceController
10. WidgetTask model

### Day 4: Widgets
11. TaskWidgetProvider
12. TodayTasksWidget
13. NextTaskWidget
14. Update TaskyWidgetsBundle
15. Interactive completion intent

### Day 5: Share Extension
16. Create TaskyShare target
17. ShareViewController
18. ShareView
19. ShareDataService

### Day 6: Siri Shortcuts
20. AddTaskIntent
21. ShowTodayIntent
22. CompleteTaskIntent
23. TaskyShortcuts provider
24. Intent donation helper
25. Update TaskyApp.swift

---

## Testing Checklist

### Calendar Integration
- [ ] Permission request shows clear explanation
- [ ] Events display correctly in day view
- [ ] External events visually distinct from tasks
- [ ] PlanDayTool avoids calendar conflicts
- [ ] Works when calendar permission denied
- [ ] Handles empty calendars gracefully

### Widgets
- [ ] Today widget shows correct tasks
- [ ] Widget updates when tasks change
- [ ] Tap opens correct app view
- [ ] Interactive completion works (iOS 17+)
- [ ] Light/dark mode support
- [ ] Dynamic Type support

### Share Extension
- [ ] Share from Safari (URL)
- [ ] Share from Notes (text)
- [ ] Quick save without opening main app
- [ ] Task appears in main app
- [ ] Haptic feedback on save

### Siri Shortcuts
- [ ] "Add task in Tasky" creates task
- [ ] "Show my tasks" opens Today view
- [ ] "Complete [task name]" marks done
- [ ] Shortcuts appear in Shortcuts app
- [ ] Siri suggestions work

---

## Files Summary

### New Files (25)
1. `Tasky/Core/Services/CalendarService.swift`
2. `Tasky/Core/Models/ExternalEvent.swift`
3. `Tasky/Features/Calendar/Views/Components/ExternalEventView.swift`
4. `Tasky/Features/Settings/Views/Components/CalendarSettingsView.swift`
5. `Shared/SharedPersistenceController.swift`
6. `Shared/WidgetTask.swift`
7. `TaskyWidgets/Providers/TaskWidgetProvider.swift`
8. `TaskyWidgets/Widgets/TodayTasksWidget.swift`
9. `TaskyWidgets/Widgets/NextTaskWidget.swift`
10. `TaskyWidgets/Intents/CompleteTaskIntent.swift`
11. `TaskyShare/ShareViewController.swift`
12. `TaskyShare/ShareView.swift`
13. `TaskyShare/ShareDataService.swift`
14. `TaskyShare/Info.plist`
15. `Tasky/Intents/AddTaskIntent.swift`
16. `Tasky/Intents/ShowTodayIntent.swift`
17. `Tasky/Intents/CompleteTaskIntent.swift`
18. `Tasky/Intents/TaskyShortcuts.swift`
19. `Tasky/Intents/IntentDonation.swift`

### Modified Files (10)
1. `Tasky/Info.plist` - Calendar permission
2. `Tasky/Features/AIChat/Tools/PlanDayTool.swift` - Calendar context
3. `Tasky/Features/Calendar/Views/Screens/DayCalendarView.swift` - External events
4. `Tasky/Features/Calendar/ViewModels/DayCalendarViewModel.swift` - External events
5. `Tasky/Core/Services/PersistenceController.swift` - App Groups
6. `TaskyWidgets/TaskyWidgetsBundle.swift` - New widgets
7. `Tasky/TaskyApp.swift` - Intent handling
8. `Tasky.xcodeproj/project.pbxproj` - New targets, capabilities

---

## Dependencies

- **EventKit** - Calendar access (system framework)
- **WidgetKit** - Home screen widgets (already imported)
- **AppIntents** - Siri shortcuts (iOS 16+)

No external SPM dependencies required.

---

## Risk Mitigation

1. **App Group Migration**: Implement one-time data migration from old store location
2. **Permission Denial**: All features gracefully degrade when permissions denied
3. **Widget Memory**: Keep widget code minimal, avoid heavy dependencies
4. **Share Extension Memory**: Use lightweight data service, not full DataService
