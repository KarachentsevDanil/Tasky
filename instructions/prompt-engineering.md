# Apple Foundation Models - Integration Guide for Task Management Apps

**Optimized system instructions for Claude Code verification of Foundation Models integration**

---

## Model Specifications & Hard Constraints

| Specification | Value |
|--------------|-------|
| Parameters | ~3B (2-bit quantized) |
| Context Window | **4096 tokens (HARD LIMIT - includes everything)** |
| Performance | 0.6ms TTFT, ~30 tok/sec (iPhone 15 Pro) |
| Platforms | iOS 26+, iPadOS 26+, macOS 26+, visionOS 26+ |
| Privacy | 100% on-device, zero cloud dependency |

### ⚠️ Critical: Model Capabilities & Limitations

**DESIGNED FOR (use these patterns):**
- Text summarization and extraction
- Entity extraction and classification
- Content tagging and categorization
- Structured data generation (@Generable)
- Tool calling for external data/actions
- Short, focused dialog
- Task-specific generation (recipes, itineraries, task parsing)

**NOT DESIGNED FOR (avoid these patterns):**
- ❌ World knowledge or trivia questions
- ❌ Advanced reasoning or multi-step logic
- ❌ Code generation
- ❌ Math calculations
- ❌ General-purpose chatbot conversations
- ❌ Long-form content generation

---

## Required Import & Availability Check

```swift
import FoundationModels

// ALWAYS check availability before creating session
let model = SystemLanguageModel.default

switch model.availability {
case .available:
    // Safe to proceed
case .unavailable(.modelNotReady):
    // Model downloading/initializing - show loading state
case .unavailable(.deviceNotEligible):
    // Device doesn't support Apple Intelligence
case .unavailable(.appleIntelligenceNotEnabled):
    // User hasn't enabled Apple Intelligence in Settings
case .unavailable(let reason):
    // Other reason - log and show fallback UI
}

// Convenience check
guard model.isAvailable else { 
    // Show appropriate fallback UI
    return 
}
```

---

## LanguageModelSession

### Initialization

```swift
// Full initializer
let session = LanguageModelSession(
    model: SystemLanguageModel.default,  // or .contentTagging for tagging tasks
    guardrails: .default,                 // CANNOT be disabled
    tools: [CompleteTaskTool(), UpdateTaskTool(), ...],
    instructions: instructions
)

// With instruction builder
let session = LanguageModelSession(tools: tools) {
    """
    You are a task management assistant.
    Keep responses under 2 sentences.
    Use tools to modify tasks - never just describe actions.
    """
}
```

### Critical Session Properties

```swift
// Check before sending new request - only ONE request at a time
guard !session.isResponding else { return }

// Pre-warm model for faster first response
await session.prewarm(promptPrefix: "Help me with my tasks")

// Access conversation history
let history = session.transcript
```

### Transcript Entry Types

```swift
for entry in session.transcript {
    switch entry {
    case .prompt(let text):
        // User input
    case .response(let response):
        // Model output: response.content
    case .instructions:
        // System instructions (don't display)
    case .toolCalls(let calls):
        // Tools the model decided to invoke
    case .toolOutput(let output):
        // Results returned from tools
    @unknown default:
        break
    }
}
```

---

## Error Handling (Complete)

```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation(let details) {
    // Content triggered safety filters
    // Common triggers: political content, survival topics, certain substrings
    // Show generic "I can't help with that" message
    
} catch LanguageModelSession.GenerationError.rateLimited {
    // Sent request while session.isResponding == true
    // Wait for current request to complete
    
} catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    // Context exceeded 4096 tokens
    // Create new session or summarize history
    
} catch let error as LanguageModelSession.ToolCallError {
    // Tool execution failed
    print("Tool failed: \(error.tool)")
    print("Reason: \(error.underlyingError)")
    
} catch {
    // Other errors
    print("Generation failed: \(error.localizedDescription)")
}
```

---

## @Generable Structured Output

### Supported Types

```swift
// ✅ Supported primitive types
String, Int, Double, Float, Decimal, Bool

// ✅ Supported compound types
Array<T> where T: Generable
Optional<T> where T: Generable
Enum with raw values
Nested @Generable structs
Recursive @Generable types

// ❌ NOT supported directly (create wrappers)
Date, URL, UUID, Data
```

### Property Order Matters

```swift
// ✅ CORRECT - context before dependents
@Generable
struct ParsedTask {
    var title: String              // Generated first
    var listName: String           // Generated second
    var priority: Priority         // Can reference title context
    var suggestedDueDate: String   // Can reference all above
}

// ❌ WRONG - dependents before context
@Generable
struct ParsedTask {
    var suggestedDueDate: String   // No context yet!
    var priority: Priority         // What task?
    var title: String              // Too late
}
```

### @Guide Constraints

```swift
@Generable
struct TaskInput {
    @Guide(description: "The task title extracted from user input")
    var title: String
    
    @Guide(description: "Priority level")
    @Guide(.anyOf(["low", "medium", "high"]))  // Enum-like constraint
    var priority: String
    
    @Guide(description: "Up to 3 relevant tags")
    @Guide(.count(3))  // Array length constraint
    var tags: [String]
    
    @Guide(description: "Due date in ISO 8601 format or natural language")
    var dueDate: String?
}
```

### Generation Methods

```swift
// Non-streaming (wait for complete result)
let result = try await session.respond(
    to: "Add buy groceries to my shopping list for tomorrow",
    generating: TaskInput.self
)
let task: TaskInput = result.content

// Streaming (get partial results)
@State var partialTask: TaskInput.PartiallyGenerated?

for try await snapshot in session.streamResponse(
    to: prompt,
    generating: TaskInput.self
) {
    partialTask = snapshot  // Properties populate incrementally
    // snapshot.title might be set while snapshot.tags is still nil
}
```

---

## Tool Implementation

### Tool Protocol Requirements

```swift
final class CompleteTaskTool: Tool {
    // REQUIRED: Short, readable name (no underscores)
    let name = "completeTask"
    
    // REQUIRED: One sentence max, include trigger words for SLM
    let description = "Mark a task as done, finished, or complete"
    
    // REQUIRED: Arguments as @Generable struct
    @Generable
    struct Arguments {
        @Guide(description: "Task title or partial match")
        let taskName: String
        
        @Guide(description: "Set to false to mark incomplete")
        let completed: Bool?
    }
    
    // REQUIRED: Implement call() method (NOT perform())
    func call(arguments: Arguments) async throws -> ToolOutput {
        let task = try await findTask(matching: arguments.taskName)
        task.isCompleted = arguments.completed ?? true
        try await save(task)
        return ToolOutput("Marked '\(task.title)' as complete")
    }
}
```

### Tool Naming Guidelines

```swift
// ✅ Good names (verb + noun, readable)
"completeTask"
"rescheduleTask"
"createList"
"getAnalytics"
"startFocusSession"

// ❌ Bad names
"complete_task"      // No underscores
"ct"                 // Too cryptic
"markTaskAsComplete" // Too long
"taskCompleter"      // Not action-oriented
```

### Tool Description Guidelines (Critical for SLM)

```swift
// ✅ GOOD - Explicit trigger words, one sentence
"Mark a task as done, finished, or complete"
"Reschedule or postpone a task to a different date"
"Show task statistics, analytics, summary, or productivity data"
"Start, stop, or check status of a focus or pomodoro session"

// ❌ BAD - Too generic or verbose
"This tool handles task completion"
"Use this to update the completion status of tasks in the database"
```

### Tool Registration

```swift
let tools: [any Tool] = [
    CompleteTaskTool(),
    UpdateTaskTool(),
    RescheduleTaskTool(),
    DeleteTaskTool(),
    ManageListTool(),
    TaskAnalyticsTool(),
    FocusSessionTool()
]

let session = LanguageModelSession(
    tools: tools,
    instructions: instructions
)
```

---

## Instructions Best Practices

### Structure for Task Management Apps

```swift
let instructions = Instructions("""
Role: Task management assistant for [App Name].
Capabilities: Create, update, complete, reschedule, delete tasks. Manage lists. Show analytics. Control focus sessions.

Rules:
- Always use tools to perform actions, never just describe them
- Match tasks by partial title if exact match not found
- Default priority: medium. Default list: Inbox
- For dates, accept: today, tomorrow, next week, Monday, specific dates
- Keep responses under 2 sentences
- If task not found, ask for clarification

Tool Selection:
- "done/finished/complete" → completeTask
- "change/update/edit/set" → updateTask  
- "move/postpone/reschedule" → rescheduleTask
- "remove/delete" → deleteTask
- "stats/summary/analytics/how am I doing" → getAnalytics
- "focus/pomodoro/concentrate" → focusSession
""")
```

### Instructions Rules

| Rule | Rationale |
|------|-----------|
| Write in English | Model trained primarily on English |
| Keep under ~100 tokens | Preserve context for conversation |
| Never interpolate user input | Prevents prompt injection |
| Include tool selection hints | Helps SLM choose correct tool |
| Specify defaults | Reduces ambiguity for small model |
| Define output format | Ensures consistent responses |

---

## Streaming Implementation

```swift
struct TaskChatView: View {
    @State private var session: LanguageModelSession?
    @State private var partialResponse: String = ""
    @State private var isGenerating = false
    
    var body: some View {
        // UI implementation
    }
    
    func sendMessage(_ text: String) async {
        guard let session, !session.isResponding else { return }
        
        isGenerating = true
        partialResponse = ""
        
        do {
            for try await chunk in session.streamResponse(to: text) {
                partialResponse = chunk.content
            }
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            partialResponse = "I can't help with that request."
        } catch {
            partialResponse = "Something went wrong. Please try again."
        }
        
        isGenerating = false
    }
}
```

---

## Context Window Management

### Budget Estimation

```
Total Available:           4096 tokens
─────────────────────────────────────
Instructions:              ~100 tokens (keep minimal)
Tool definitions:          ~50 tokens per tool
Conversation history:      Variable
Current prompt:            Variable
Response buffer:           ~500-1000 tokens
─────────────────────────────────────

With 7 tools + instructions: ~450 tokens overhead
Remaining for conversation: ~3646 tokens
```

### Management Strategies

```swift
// 1. Monitor and reset when approaching limit
func checkContextAndReset() async {
    // If getting exceededContextWindowSize errors, reset
    if shouldResetSession {
        // Optionally summarize important context first
        session = LanguageModelSession(tools: tools, instructions: instructions)
    }
}

// 2. Keep individual messages focused
// ❌ Long prompt with lots of context
"I have this task called buy groceries that I added yesterday and it's in my shopping list and I want to mark it as done because I finished it"

// ✅ Concise prompt
"Mark buy groceries as done"

// 3. Use tools for data instead of context stuffing
// ❌ Don't embed all tasks in prompt
"Here are my tasks: [500 tasks...]. Which ones are due today?"

// ✅ Let tool fetch relevant data
struct GetTasksTool: Tool {
    func call(arguments: Arguments) async throws -> ToolOutput {
        let todayTasks = fetchTasks(filter: .dueToday)
        return ToolOutput(todayTasks.map(\.title).joined(separator: ", "))
    }
}
```

---

## Guardrails & Safety

### Current State (iOS 26)

- Guardrails are **always enabled** - cannot be disabled
- Scan both input (prompts) and output (responses)
- Common false positives reported by developers:
  - Political news content
  - Survival/hunting topics
  - Medical/health queries
  - Certain technical substrings

### Handling Guardrail Errors

```swift
catch LanguageModelSession.GenerationError.guardrailViolation(let info) {
    // Don't expose internal error details to user
    // Show generic, friendly message
    return "I'm not able to help with that particular request. Could you try rephrasing?"
}
```

### Safety-Conscious Instructions

```swift
let instructions = Instructions("""
You are a helpful task assistant.
Only discuss task management, productivity, and related topics.
Decline requests unrelated to task management politely.
Never provide harmful, illegal, or inappropriate content.
""")
```

---

## Multilingual Support

```swift
// Instructions: Always in English (best model performance)
// Prompts: Can be in user's language
// Output: Matches prompt language automatically

let userLocale = Locale.current.language.languageCode?.identifier ?? "en"

let instructions = Instructions("""
You are a task assistant.
The user's preferred language is: \(userLocale)
Always respond in the user's language.
Keep responses concise.
""")

// User can now prompt in their language
// "Marca la tarea de compras como completada" → Spanish response
```

---

## Validation Rules for Claude Code

```yaml
# Use this section for automated verification

imports:
  required:
    - FoundationModels
  optional:
    - Playgrounds  # For testing only

availability_check:
  required: true
  pattern: "SystemLanguageModel.default.availability"
  must_handle:
    - .available
    - .unavailable(.modelNotReady)
    - .unavailable(.deviceNotEligible)
    - .unavailable(.appleIntelligenceNotEnabled)

session:
  must_check_isResponding_before_request: true
  should_use_prewarm_for_predictable_calls: true
  
error_handling:
  required_catches:
    - LanguageModelSession.GenerationError.guardrailViolation
    - LanguageModelSession.GenerationError.rateLimited
    - LanguageModelSession.GenerationError.exceededContextWindowSize
    - LanguageModelSession.ToolCallError

generable:
  property_order: "context_before_dependents"
  supported_types:
    - String
    - Int
    - Double
    - Float
    - Decimal
    - Bool
    - Array<Generable>
    - Optional<Generable>
    - Enum (with raw values)
    - Nested Generable structs
  unsupported_types:
    - Date  # Use String with ISO 8601
    - URL   # Use String
    - UUID  # Use String
    - Data  # Not supported
  guide_macro:
    - use_for_ambiguous_properties: true
    - constraints: [".anyOf()", ".count()"]

tool:
  protocol_method: "call(arguments:)"  # NOT perform()
  return_type: "ToolOutput"
  required_properties:
    - name: "String, no underscores, readable English"
    - description: "String, one sentence max, include trigger words"
  arguments:
    - must_be_generable: true
    - use_guide_for_all_properties: recommended

instructions:
  language: "English only"
  max_tokens: 100
  must_not_interpolate_user_input: true
  recommended_sections:
    - Role definition
    - Capabilities list
    - Rules/constraints
    - Tool selection hints
    - Output format

antipatterns:
  - world_knowledge_queries
  - code_generation_requests
  - math_calculations
  - long_context_stuffing
  - multiple_simultaneous_requests
  - verbose_instructions
  - user_input_in_instructions
```

---

## Task App Specific Patterns

### Fuzzy Task Matching in Tools

```swift
func findTask(matching query: String) throws -> Task {
    let allTasks = fetchAllTasks()
    
    // Priority: exact > prefix > contains > word match
    if let exact = allTasks.first(where: { $0.title.lowercased() == query.lowercased() }) {
        return exact
    }
    if let prefix = allTasks.first(where: { $0.title.lowercased().hasPrefix(query.lowercased()) }) {
        return prefix
    }
    if let contains = allTasks.first(where: { $0.title.lowercased().contains(query.lowercased()) }) {
        return contains
    }
    
    throw ToolError.taskNotFound(query)
}
```

### Natural Language Date Parsing

```swift
@Generable
struct RescheduleArguments {
    @Guide(description: "Task to reschedule")
    let taskName: String
    
    @Guide(description: "When to reschedule: today, tomorrow, next_week, monday, tuesday, etc., or ISO 8601 date")
    @Guide(.anyOf(["today", "tomorrow", "next_week", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]))
    let when: String
}

func parseDate(_ input: String) -> Date? {
    switch input.lowercased() {
    case "today": return .now
    case "tomorrow": return Calendar.current.date(byAdding: .day, value: 1, to: .now)
    case "next_week": return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: .now)
    case "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday":
        return nextWeekday(named: input)
    default:
        // Try ISO 8601
        return ISO8601DateFormatter().date(from: input)
    }
}
```

### Tool Output Formatting

```swift
// Keep tool outputs concise - they go back into context
func call(arguments: Arguments) async throws -> ToolOutput {
    // ✅ Good - concise, actionable
    return ToolOutput("Marked 'Buy groceries' complete")
    return ToolOutput("Rescheduled to tomorrow")
    return ToolOutput("Created list 'Work' with 🔵")
    
    // ❌ Bad - verbose, wastes context
    return ToolOutput("I have successfully marked the task titled 'Buy groceries' as complete in your task database. The completion date has been recorded as...")
}
```

### Analytics Tool Pattern

```swift
@Generable
struct AnalyticsArguments {
    @Guide(description: "Type of analytics to show")
    @Guide(.anyOf([
        "daily_summary",
        "weekly_summary",
        "monthly_summary",
        "completion_rate",
        "streak",
        "overdue",
        "productivity_score",
        "busiest_day",
        "category_breakdown",
        "upcoming"
    ]))
    let type: String
    
    @Guide(description: "Optional date range start")
    let startDate: String?
    
    @Guide(description: "Optional date range end")
    let endDate: String?
}
```

---

## Quick Reference

### Session Lifecycle

```
1. Check availability
2. Create session with tools + instructions
3. Optional: prewarm()
4. Check isResponding before each request
5. Handle all error types
6. Monitor context usage
7. Reset session when needed
```

### Token Budget Cheat Sheet

| Component | Approximate Tokens |
|-----------|-------------------|
| Minimal instructions | 50-100 |
| Each tool definition | 30-50 |
| Short user message | 10-30 |
| Short model response | 20-50 |
| Tool call + result | 30-60 |

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| `guardrailViolation` | Rephrase prompt, show generic error |
| `rateLimited` | Check `isResponding` before requests |
| `exceededContextWindowSize` | Reset session, reduce instructions |
| Tool not called | Add explicit trigger words to description |
| Wrong tool called | Add tool selection hints to instructions |
| Poor output quality | Use @Guide constraints, specify format |

---

## Resources

- [Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [WWDC25: Meet Foundation Models](https://developer.apple.com/videos/play/wwdc2025/286/)
- [WWDC25: Deep Dive](https://developer.apple.com/videos/play/wwdc2025/301/)
- [WWDC25: Code-along](https://developer.apple.com/videos/play/wwdc2025/259/)
- [TN3193: Managing Context Window](https://developer.apple.com/documentation/technotes/tn3193)
- [Acceptable Use Guidelines](https://developer.apple.com/documentation/foundationmodels/acceptable-use)

---

**Document Version:** 2.0  
**Last Updated:** November 2025  
**Target:** iOS 26+ / Xcode 26+  
**Use Case:** Task Management App with AI Tools