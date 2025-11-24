# CLAUDE.md

Project guidance for Claude Code when working with Tasky.

## Build Commands

```bash
# Build for simulator
xcodebuild -scheme Tasky -sdk iphonesimulator build

# Clean build
xcodebuild -scheme Tasky -sdk iphonesimulator clean build

# Check errors/warnings
xcodebuild -scheme Tasky -sdk iphonesimulator build 2>&1 | grep -E "(error:|warning:|BUILD)"
```

## Architecture

**MVVM + Core Data** with strict separation:

```
Views (SwiftUI) → ViewModels (@MainActor, @Published) → DataService → PersistenceController (Core Data)
```

**Key Principles:**
1. **Single ViewModel Pattern**: One `TaskListViewModel` shared across all tabs (passed from ContentView)
2. **Internal Core Data**: Always use `internal import CoreData` for proper access control
3. **Async/Await**: All data operations are async, called from `Task {}` blocks
4. **Sheet Presentations**: Use `NavigationRow` component for form navigation (not NavigationLink)

## Core Data Entities

- **TaskEntity**: Tasks with scheduling, priority, focus tracking
- **TaskListEntity**: Custom lists/projects
- **FocusSessionEntity**: Pomodoro sessions (infrastructure ready)

**Critical Fields:**
- `TaskEntity.scheduledTime/scheduledEndTime` - Time blocking
- `TaskEntity.priorityOrder` - Drag reordering
- `TaskEntity.focusTimeSeconds` - Total focus time

## Key Components

**NavigationRow**: Sheet-based progressive disclosure for forms
- Eliminates double chevrons (uses sheets, not NavigationLink)
- Includes haptic feedback

**TimeSlotPickerView**: Visual time picker with 15-min increments
- Shows time blocks in accent color
- Duration options: 1m, 15m, 30m, 45m, 1h, 1.5h

**DatePickerView**: Simplified date selection
- Quick actions: Today, Tomorrow, +3 days
- Graphical picker for custom dates

**HapticManager**: Haptics singleton
- `.success()` - Task completion
- `.lightImpact()` - Button taps
- `.selectionChanged()` - Picker changes

## Essential Patterns

### Adding Views

**Screen Views:**
- Place in `Views/Screens/`
- Use `@ObservedObject var viewModel: TaskListViewModel` (passed from parent)
- Use `@FocusState` for input focus management
- Always add `#Preview` with `.preview` persistence controller
- NO NavigationStack wrapper (parent provides it)

**Reusable Components:**
- Place in `Views/Components/`
- Accept data via `let` properties (no state)
- Use callbacks for actions

### AddTaskView Presentation

**IMPORTANT**: AddTaskView is presented via **navigation**, NOT sheets/modals.

```swift
// In parent view
@State private var showingAddTask = false

// Navigation presentation (✅ Correct)
.navigationDestination(isPresented: $showingAddTask) {
    AddTaskView(viewModel: viewModel)
}

// ❌ NEVER use sheet presentation for AddTaskView
// .sheet(isPresented: $showingAddTask) {
//     AddTaskView(viewModel: viewModel)  // WRONG!
// }
```

**Why Navigation?**
- Provides standard back button
- No modal stacking
- Swipe from edge to go back
- Consistent with iOS design patterns
- AddTaskView has NO NavigationStack wrapper

### Input Focus Pattern

```swift
@FocusState private var isTitleFocused: Bool

TextField("Title", text: $title)
    .focused($isTitleFocused)

.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isTitleFocused = true
    }
}
```

### Navigation Pattern

**Two Approaches - Choose Based on Complexity:**

1. **InlineExpandableRow** - For simple pickers (PREFERRED)
   - Expands/collapses within Form
   - No modal stacking
   - Better UX for simple selections
   - Examples: Date, Priority, Tags

```swift
// Inline expansion - no modal
InlineExpandableRow(
    icon: "calendar",
    iconColor: .blue,
    label: "Due Date",
    value: "Today"
) {
    InlineDatePicker(dueDate: $dueDate)
}
```

2. **NavigationRow** - For complex forms only
   - Presents full-screen sheet
   - Use when content needs space
   - Examples: Notes editor, Time picker, List selection

```swift
// Sheet presentation - for complex content
NavigationRow(
    icon: "clock",
    iconColor: .orange,
    label: "Scheduled Time",
    value: "2:00 PM - 3:00 PM"
) {
    TimeSlotPickerView(
        scheduledTime: $scheduledTime,
        scheduledEndTime: $scheduledEndTime,
        hasScheduledTime: $hasScheduledTime,
        selectedDate: dueDate ?? Date()
    )
}
```

**Rule of Thumb:**
- Simple selection (< 5 options) → InlineExpandableRow
- Complex UI or multi-step → NavigationRow
- Avoid stacking modals - use inline when possible

## Constants

Never hardcode values. Use `Constants.swift`:
- `Constants.Spacing.*` - 8pt grid (xs, sm, md, lg, xl)
- `Constants.IconSize.*` - Icon sizes
- `Constants.Layout.*` - Tap targets, corner radius
- `Constants.Animation.Spring.*` - Animation parameters
- `Constants.Icons.*` - SF Symbol names

## Data Flow

```swift
// View triggers action
Task { await viewModel.toggleTaskCompletion(task) }

// ViewModel handles business logic
func toggleTaskCompletion(_ task: TaskEntity) async {
    try dataService.toggleTaskCompletion(task)
    await loadTasks()  // Refresh UI
}
```

## Core Data Changes

When modifying entities:
1. Update `.xcdatamodeld` XML
2. Update `+CoreDataProperties.swift`
3. Update `DataService` create/update methods
4. Update `PersistenceController.preview` sample data
5. Clean build

## App Structure

**5-Tab Layout:**
1. Today - Daily focus view
2. Calendar - Day/Week/Month with time blocking
3. AI Chat - Natural language task creation (iOS 26+)
4. Progress - Stats and achievements
5. Lists - (TBD)

## AI Integration (iOS 26+)

Uses Apple's **FoundationModels** framework:
- `AIChatViewModel` manages LLM session
- `CreateTasksTool` handles task creation via tool calling
- On-device processing with Apple Intelligence

**Availability Check:**
```swift
SystemLanguageModel.default.availability
```

## Voice Input

- `VoiceInputManager` handles speech recognition
- Requires permissions in Info.plist:
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription`

## Important Notes

- **Filter System**: ViewModel uses `FilterType` enum (all, today, upcoming, inbox, completed, list)
- **List Colors**: Hex strings in Core Data, converted via `Color(hex:)` extension
- **Celebrations**: Use `HapticManager.shared.success()` + confetti for completions
- **Preview Data**: Use `PersistenceController.preview` for all SwiftUI previews
