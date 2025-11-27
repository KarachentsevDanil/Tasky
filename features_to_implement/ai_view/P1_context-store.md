# Context Store (AI Memory System)

**Priority:** P1
**View Area:** ai_view
**Status:** NOT_STARTED

## Problem
AI has no memory between sessions. Every conversation starts fresh. Can't learn user's people, preferences, schedule patterns, or goals. The "learns you" value proposition requires persistent context.

## Requirements

### Must Have
- [ ] Create UserContextEntity in Core Data
- [ ] Fields: id, category, key, value, confidence, source, timestamps
- [ ] Categories: person, preference, schedule, goal, constraint, pattern
- [ ] Sources: explicit (user said "remember"), extracted (from tasks), inferred (patterns)
- [ ] Confidence scoring (0.0 - 1.0)
- [ ] Confidence decay over time (memories fade if not reinforced)
- [ ] Confidence reinforcement on repeated mentions
- [ ] "remember" AI tool - explicit memory storage
- [ ] "recall" AI tool - retrieve stored context
- [ ] "forgetContext" AI tool - delete stored context
- [ ] Context injection into AI prompts (relevant context only)

### Should Have
- [ ] Passive extraction from task creation (people, goals)
- [ ] Pattern detection (completion times, productivity peaks)
- [ ] Memory management UI (view/edit/delete what Tasky knows)
- [ ] Automatic pruning of low-confidence stale items
- [ ] Maximum item limits (100 items cap)

## Confidence System

| Source | Base Confidence | Half-Life |
|--------|-----------------|-----------|
| explicit | 0.85 | 180 days |
| extracted | 0.50 | 60 days |
| inferred | 0.30 | 30 days |

## Data Model

### UserContextEntity Fields
| Field | Type | Purpose |
|-------|------|---------|
| id | UUID | Unique identifier |
| category | String | person, preference, schedule, goal, constraint, pattern |
| key | String | Normalized lookup key (lowercase, trimmed) |
| value | String | Human-readable information |
| confidence | Float | 0.0 - 1.0 certainty score |
| source | String | explicit, extracted, inferred |
| createdAt | Date | When first captured |
| updatedAt | Date | Last modification |
| lastAccessedAt | Date? | Last used in AI context |
| accessCount | Int | Times retrieved for prompts |
| reinforcementCount | Int | Times user mentioned this |
| metadata | Data? | JSON for category-specific data |

## Components Affected

### Files to Create
- `Models/UserContextEntity.swift` - Core Data entity
- `Services/ContextStore.swift` - CRUD and retrieval logic
- `Services/ConfidenceDecay.swift` - Decay/reinforcement calculations
- `Services/AI/Tools/RememberTool.swift` - Explicit memory tool
- `Services/AI/Tools/RecallTool.swift` - Retrieval tool
- `Services/AI/Tools/ForgetContextTool.swift` - Deletion tool
- `Views/Settings/MemoryManagementView.swift` - User memory UI

### Files to Modify
- `Tasky.xcdatamodeld` - Add UserContextEntity
- `Services/AI/AIService.swift` - Inject context into prompts
- `Services/AI/Tools/PlanDayTool.swift` - Use context for planning
- `Services/AI/Tools/CreateTasksTool.swift` - Extract context on creation

## Key Notes
- All data stays on-device (privacy-first)
- Token budget: ~150 tokens max for context injection
- Must be transparent - users see everything stored
- Requires Core Data migration
- See ContextStore specification document for full architectural details
