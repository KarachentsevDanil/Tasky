# Tasky Feature Specifications

This directory contains prioritized feature specifications for Tasky iOS app development.

## Directory Structure

```
features_to_implement/
├── ai_view/           # AI Coach chat interface features
├── today_view/        # Today's tasks view features
├── calendar_view/     # Calendar and time-blocking features
├── tasks_list/        # Task list and management features
├── settings/          # Settings and preferences features
└── global/            # Cross-cutting features
```

## Priority Levels

| Priority | Meaning | Action |
|----------|---------|--------|
| **P0** | Critical | Implement immediately - blockers |
| **P1** | High | Next sprint - high impact |
| **P2** | Medium | Near future - good improvements |
| **P3** | Low | Backlog - nice to have |

## Feature Summary

### P0 - Critical (1 feature)
| Feature | View Area | File |
|---------|-----------|------|
| Calendar Read Access | global | `P0_calendar-read-access.md` |

### P1 - High Priority (7 features)
| Feature | View Area | File |
|---------|-----------|------|
| Subtasks & Checklists | global | `P1_subtasks-checklists.md` |
| Home Screen Widgets | global | `P1_home-screen-widgets.md` |
| Siri Shortcuts | global | `P1_siri-shortcuts.md` |
| Share Extension | global | `P1_share-extension.md` |
| Proactive AI Suggestions | ai_view | `P1_proactive-suggestions.md` |
| Context Store (Memory) | ai_view | `P1_context-store.md` |
| Flexible Recurring Tasks | tasks_list | `P1_recurring-tasks-flex.md` |

### P2 - Medium Priority (7 features)
| Feature | View Area | File |
|---------|-----------|------|
| Apple Watch App | global | `P2_apple-watch-app.md` |
| Tags & Labels | tasks_list | `P2_tags-labels.md` |
| Task Dependencies | tasks_list | `P2_task-dependencies.md` |
| Bulk Operations | tasks_list | `P2_bulk-operations.md` |
| Morning Brief | today_view | `P2_morning-brief.md` |
| Weekly Review Flow | settings | `P2_weekly-review.md` |
| Time Estimation Learning | ai_view | `P2_time-estimation-learning.md` |

### P3 - Low Priority (5 features)
| Feature | View Area | File |
|---------|-----------|------|
| Focus Modes Integration | global | `P3_focus-modes.md` |
| Spotlight Search | global | `P3_spotlight-search.md` |
| Location-Based Tasks | tasks_list | `P3_location-tasks.md` |
| Task Attachments | tasks_list | `P3_task-attachments.md` |
| Goal Progress Tracking | settings | `P3_goal-progress.md` |

## Recommended Implementation Order

### Phase 1: Foundation
1. `P0_calendar-read-access.md` - Unblocks AI planning

### Phase 2: Core "Learns You"
2. `P1_context-store.md` - Memory system foundation
3. `P1_subtasks-checklists.md` - Essential task model

### Phase 3: Capture Friction
4. `P1_siri-shortcuts.md` - Voice capture
5. `P1_share-extension.md` - Capture from anywhere

### Phase 4: Visibility
6. `P1_home-screen-widgets.md` - Home screen presence

### Phase 5: Intelligence
7. `P1_proactive-suggestions.md` - AI initiation
8. `P1_recurring-tasks-flex.md` - Table stakes

### Phase 6+: Iterate
9. P2 features based on user feedback

## Spec Format

Each spec follows this structure:

```markdown
# Feature Name

**Priority:** P0 | P1 | P2 | P3
**View Area:** [area]
**Status:** NOT_STARTED

## Problem
[What user problem this solves]

## Requirements

### Must Have
- [ ] Requirement 1
- [ ] Requirement 2

### Should Have
- [ ] Nice-to-have 1

## Components Affected

### Files to Modify
- `Path/To/File.swift` - [what changes]

### Files to Create
- `Path/To/NewFile.swift` - [purpose]

## Key Notes
- [Important considerations]
```

## Status Values

- `NOT_STARTED` - Spec complete, not yet in development
- `IN_PROGRESS` - Currently being implemented
- `IN_REVIEW` - Implementation complete, under review
- `COMPLETE` - Shipped

## Dependencies

Some features depend on others:

```
P0_calendar-read-access
    └── P2_morning-brief (needs calendar for meeting awareness)

P1_context-store
    ├── P1_proactive-suggestions (needs memory for triggers)
    └── P2_time-estimation-learning (needs context for insights)

P1_subtasks-checklists
    └── AI suggestBreakdown tool (creates actual subtasks)

P2_tags-labels
    └── P2_bulk-operations (bulk add/remove tags)
```

## Usage

1. Pick a feature from current phase
2. Read the spec thoroughly
3. Update status to `IN_PROGRESS`
4. Implement following the requirements
5. Update status to `IN_REVIEW` when done
6. Move to `COMPLETE` after merge

---

*Generated: November 2024*
*Total Features: 20*
