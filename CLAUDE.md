# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

**Build for simulator:**
```bash
xcodebuild -scheme Tasky -sdk iphonesimulator build
```

**Clean build:**
```bash
xcodebuild -scheme Tasky -sdk iphonesimulator clean build
```

**Check for errors/warnings:**
```bash
xcodebuild -scheme Tasky -sdk iphonesimulator build 2>&1 | grep -E "(error:|warning:|BUILD)"
```

**List available simulators:**
```bash
xcodebuild -scheme Tasky -showdestinations
```

## Architecture Overview

Tasky follows **MVVM + Core Data** architecture with strict separation of concerns:

```
┌─────────────────┐
│  SwiftUI Views  │ ← User interactions
└────────┬────────┘
         │ @StateObject/@ObservedObject
┌────────▼────────┐
│   ViewModels    │ ← @Published properties, Combine
└────────┬────────┘
         │ Uses
┌────────▼────────┐
│   DataService   │ ← Business logic layer
└────────┬────────┘
         │ Uses
┌────────▼─────────────┐
│ PersistenceController│ ← Core Data stack
└──────────────────────┘
```

### Key Principles

1. **Single ViewModel Pattern**: All views share one `TaskListViewModel` instance passed down from `ContentView`. This ensures consistent state across tabs.

2. **Internal Core Data Imports**: All Core Data imports use `internal import CoreData` to maintain proper access control and avoid public API leakage.

3. **Identifiable Protocol**: Both `TaskEntity` and `TaskListEntity` conform to `Identifiable` via extensions. The `id` property must be marked `public` for SwiftUI's `ForEach` to work.

4. **Async/await**: All data operations in ViewModel are async functions called from `Task {}` blocks to keep the UI responsive.

## Core Data Model

**Entities:**
- `TaskEntity` - Individual tasks with scheduling, priority, and focus tracking
- `TaskListEntity` - Custom lists/projects for organizing tasks
- `FocusSessionEntity` - Pomodoro-style focus sessions (infrastructure ready, UI not yet implemented)

**Critical Fields:**
- `TaskEntity.priorityOrder` - For drag-to-reorder functionality (infrastructure ready)
- `TaskEntity.scheduledTime` - For calendar time blocking
- `TaskEntity.focusTimeSeconds` - Tracks total focus time per task
- `TaskEntity.priority` - Task priority level (0-3)

**Relationships:**
- `TaskEntity.taskList` → `TaskListEntity` (many-to-one)
- `TaskEntity.focusSessions` → `FocusSessionEntity` (one-to-many, cascade delete)
- `TaskListEntity.tasks` → `TaskEntity` (one-to-many, cascade delete)

## Data Flow Pattern

All CRUD operations follow this pattern:

1. **View** triggers action (button tap, swipe)
2. **ViewModel** receives action via `async` function
3. **ViewModel** calls **DataService** method (throws errors)
4. **DataService** manipulates Core Data entities
5. **DataService** saves via `PersistenceController`
6. **ViewModel** reloads data (updates `@Published` properties)
7. **View** automatically updates via SwiftUI bindings

Example:
```swift
// View
Task {
    await viewModel.toggleTaskCompletion(task)
}

// ViewModel
func toggleTaskCompletion(_ task: TaskEntity) async {
    do {
        try dataService.toggleTaskCompletion(task)
        await loadTasks()  // Refresh
    } catch {
        handleError(error)
    }
}
```

## Component Architecture

### Reusable UI Components

**CompletionRingView**: Animated circular progress ring
- Two variants: standard (120x120) and compact (40x40)
- Auto-animates on appear and on progress changes
- Color changes based on completion percentage

**ConfettiView**: Particle-based celebration animation
- 50 particles by default
- 1.5-second animation
- Use via `.confetti(isPresented: $bool)` modifier
- Auto-dismisses after animation

**HapticManager**: Singleton for haptic feedback
- `HapticManager.shared.success()` - Task completion
- `HapticManager.shared.lightImpact()` - Button taps
- `HapticManager.shared.mediumImpact()` - Drag events
- User can toggle haptics via UserDefaults

### View Hierarchy

**5-Tab Structure** ([ContentView.swift:1](ContentView.swift#L1)):
1. **TodayView** - Daily focus with completion tracking
2. **UpcomingView** (Calendar tab) - Day/Week/Month views with time blocking
3. **AIChatView** (AI tab) - Natural language task creation via Apple Intelligence
4. **ProgressTabView** - Stats and achievements
5. _(Lists tab TBD)_

All tabs share the same `TaskListViewModel` instance initialized in `ContentView`. The AI tab uses its own `AIChatViewModel` with access to the shared `DataService`.

## Important Patterns

### Filter System

ViewModel uses `currentFilter` enum to determine which tasks to show:
```swift
enum FilterType {
    case all
    case today      // Due today
    case upcoming   // Next 7 days
    case inbox      // No list assigned
    case completed  // isCompleted = true
    case list(TaskListEntity)
}
```

### Constants Usage

Never hardcode strings or magic numbers. Use `Constants.swift`:
- `Constants.Icons.*` - SF Symbol names
- `Constants.UI.*` - Spacing, sizing
- `Constants.Colors.*` - Predefined color palette
- `Constants.TaskPriority` - Priority enum with colors

### Preview Data

Use `PersistenceController.preview` for SwiftUI previews:
```swift
#Preview {
    TaskListView(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        filterType: .today,
        title: "Today"
    )
}
```

## Modifying Core Data Model

⚠️ **Important**: When adding/removing Core Data attributes:

1. Update `TaskTracker.xcdatamodeld/TaskTracker.xcdatamodel/contents` XML
2. Update corresponding `+CoreDataProperties.swift` file with `@NSManaged` properties
3. Update `DataService.createTask()` and `updateTask()` methods
4. Update `PersistenceController.preview` sample data if needed
5. Rebuild - Core Data changes require clean build sometimes

## Adding New Views

Pattern for new screen views:

1. Create in `Views/Screens/`
2. Add `@StateObject var viewModel: TaskListViewModel` (passed from parent)
3. Use `@State` for local UI state only
4. Call `await viewModel.loadTasks()` in `.task {}` modifier
5. Add `#Preview` with preview persistence controller

Pattern for reusable components:

1. Create in `Views/Components/`
2. Accept data via `let` properties (no state)
3. Use callbacks for actions: `let onToggleCompletion: () -> Void`
4. Add multiple `#Preview` variants showing different states

## Celebration Effects

When completing tasks, trigger celebrations:

```swift
private func celebrateCompletion() {
    HapticManager.shared.success()      // Haptic
    showConfetti = true                 // Confetti
    // Confetti auto-dismisses after 1.5s
}
```

Pattern used in TodayView - can be replicated in other views.

## List Color System

Lists use hex color strings stored in Core Data:
- `TaskListEntity.colorHex` - Hex string (e.g., "007AFF")
- `TaskListEntity.color` - Computed property returning SwiftUI `Color`
- `Color+Hex.swift` provides `Color(hex:)` initializer

8 predefined colors available in `Constants.Colors.listColors`.

## AI Chat Integration (iOS 26+)

Tasky includes an AI-powered chat assistant using Apple's **FoundationModels** framework for natural language task creation.

### Architecture

```
┌──────────────┐
│ AIChatView   │ ← SwiftUI chat interface
└──────┬───────┘
       │ @StateObject
┌──────▼────────────┐
│ AIChatViewModel   │ ← Session management, streaming
└──────┬────────────┘
       │ Uses
┌──────▼────────────────┐
│ LanguageModelSession  │ ← Apple's on-device LLM
└──────┬────────────────┘
       │ Tool calling
┌──────▼────────────┐
│ CreateTasksTool   │ ← @Generable Tool protocol
└──────┬────────────┘
       │ Creates
┌──────▼──────────┐
│   DataService   │ ← Saves tasks to Core Data
└─────────────────┘
```

### Key Components

**AIChatViewModel** ([AIChatViewModel.swift:1](AIChatViewModel.swift#L1))
- Checks `SystemLanguageModel.default.availability` on init
- Creates `LanguageModelSession` with system instructions and tools
- Streams responses using `session.streamResponse(to:)`
- Updates UI incrementally as tokens arrive

**CreateTasksTool** ([CreateTasksTool.swift:1](CreateTasksTool.swift#L1))
- Conforms to `Tool` protocol from FoundationModels
- Uses `@Generable` macro for automatic argument parsing
- Uses `@Guide` descriptions for each field to help LLM understanding
- Supports multiple tasks in one call
- Parses ISO 8601 dates for due dates and scheduled times

**AIChatView** ([AIChatView.swift:1](AIChatView.swift#L1))
- iMessage-style chat interface
- Auto-scrolling message history
- Typing indicator during generation
- Availability detection with fallback UI

### Availability

The AI features require:
- iOS 26 or later (FoundationModels framework)
- Apple Intelligence enabled in Settings
- Compatible device with on-device model support

Check availability:
```swift
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // Set up session
case .unavailable(let reason):
    // Show fallback UI
}
```

### Tool Calling Flow

1. User sends message: "Create a task to buy groceries tomorrow"
2. LLM decides to call `create_tasks` tool
3. Framework parses arguments into `CreateTasksTool.Arguments`
4. Tool's `call(arguments:)` method executes:
   - Parses dates from ISO 8601
   - Validates priority values
   - Creates tasks via DataService
   - Returns formatted success message as `GeneratedContent`
5. LLM incorporates tool result into response
6. User sees confirmation: "✓ Created task: Buy Groceries"

### Adding New Tools

Follow this pattern for new AI capabilities:

```swift
import FoundationModels

struct MyTool: Tool {
    let name = "my_tool"
    let description = "Clear description for LLM"

    @Generable
    struct Arguments {
        @Guide(description: "Help text")
        let param: String
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Execute action
        return GeneratedContent("Result message")
    }
}
```

Then register in `LanguageModelSession`:
```swift
session = LanguageModelSession(
    model: SystemLanguageModel.default,
    tools: [CreateTasksTool(), MyTool()],
    instructions: "..."
)
```

### Testing AI Features

- Simulator: AI may not be available (device-specific)
- Device: Requires Apple Intelligence enrollment
- Check console for availability reason if unavailable
- Test tool calling with explicit phrases: "Create a task to..."

### System Instructions

Keep instructions clear and action-oriented:
- Define assistant role/personality
- List available tools and when to use them
- Specify output format preferences
- Keep concise (long instructions = more context usage)

## Voice Input Feature

Tasky includes voice dictation for the AI chat, allowing users to create tasks by speaking instead of typing.

### Architecture

```
User taps mic button
    ↓
VoiceInputManager requests permissions
    ↓
Speech recognition starts (SFSpeech + AVAudioEngine)
    ↓
Transcription streams to AIChatView
    ↓
User taps stop → Auto-sends to AI
    ↓
Task created via normal AI flow
```

### Components

**VoiceInputManager.swift**
- Manages speech recognition lifecycle
- Handles microphone permissions (AVAudioSession)
- Handles speech recognition permissions (SFSpeechRecognizer)
- Streams partial transcription results
- MainActor-isolated for SwiftUI updates

**AIChatView Updates**
- Microphone button (blue mic icon → red stop icon when recording)
- Recording indicator with animated pulse
- Real-time transcription preview
- Auto-send on stop recording
- Permission alert for denied access

### Required Permissions

Add these to your Xcode project settings (Info tab):

1. **Privacy - Speech Recognition Usage Description**
   - Key: `NSSpeechRecognitionUsageDescription`
   - Value: "Tasky needs speech recognition to allow you to create tasks using voice input."

2. **Privacy - Microphone Usage Description**
   - Key: `NSMicrophoneUsageDescription`
   - Value: "Tasky needs microphone access to transcribe your voice into tasks."

⚠️ **Important**: These permissions MUST be added in Xcode project settings. The app will crash if you try to use voice input without them.

### Adding Permissions in Xcode

1. Open Tasky.xcodeproj in Xcode
2. Select the Tasky target
3. Go to the Info tab
4. Click the + button under "Custom iOS Target Properties"
5. Add both keys with their descriptions

### Usage Flow

1. User opens AI chat tab
2. Taps microphone button
3. First time: Permission alert appears
4. User grants permissions
5. Recording starts (red indicator shows)
6. Speech is transcribed in real-time
7. User taps stop button
8. Message auto-sends to AI
9. AI creates task as normal

### Troubleshooting

**"Speech recognition not authorized"**
- User denied speech recognition permission
- Show alert directing to Settings

**"Microphone access not authorized"**
- User denied microphone permission
- Show alert directing to Settings

**"Speech recognition not available"**
- Device doesn't support speech recognition
- Simulator limitations
- Fall back to keyboard input

### Testing

- Real device: Full functionality
- Simulator: May have limitations with microphone/speech
- Test permission flows: deny → settings → re-enable
- Test auto-send after recording stops
