# Proactive AI Suggestions

**Priority:** P1
**View Area:** ai_view
**Status:** NOT_STARTED

## Problem
AI only responds to user input, never initiates. Valuable insights exist but aren't surfaced. Users must remember to ask. The "learns you" promise stays invisible without proactive engagement.

## Requirements

### Must Have
- [ ] Define suggestion trigger conditions (see list below)
- [ ] Create notification/prompt system for suggestions
- [ ] "Task rescheduled 3+ times" → offer breakdown or deletion
- [ ] "Goal neglected 5+ days" → nudge about goal
- [ ] "All tasks completed today" → celebration message
- [ ] "Overdue tasks accumulating (5+)" → triage prompt
- [ ] User can dismiss/snooze suggestions
- [ ] Respect notification preferences

### Should Have
- [ ] "Context birthday approaching" → reminder prompt
- [ ] "Unusual productivity" → encouragement
- [ ] "Streak milestone" → celebration
- [ ] "Weekly review time" → prompt on Sunday evening
- [ ] Suggestions appear in AI chat as assistant-initiated messages
- [ ] Learn which suggestions user engages with vs dismisses

## Trigger Conditions

| Trigger | Condition | Suggestion |
|---------|-----------|------------|
| Stuck task | rescheduled >= 3 times | "Break down or delete?" |
| Neglected goal | no related tasks completed in 5 days | "Want to work on [goal]?" |
| Overdue pile | overdue count >= 5 | "Let's triage these" |
| Clean slate | all today tasks done | "Great work! 🎉" |
| Birthday soon | context birthday within 5 days | "Mom's birthday in 3 days" |
| Streak milestone | streak hits 7, 30, 100 | Celebration |

## Components Affected

### Files to Create
- `Services/ProactiveSuggestionService.swift` - Trigger evaluation logic
- `Models/Suggestion.swift` - Suggestion model
- `Views/AI/SuggestionBannerView.swift` - In-app suggestion display

### Files to Modify
- `Views/AI/AIChatView.swift` - Display proactive messages
- `ViewModels/AIChatViewModel.swift` - Handle suggestion interactions
- `Services/NotificationService.swift` - Schedule suggestion notifications

## Key Notes
- Balance helpfulness vs annoyance - max 1-2 suggestions per day
- Track suggestion engagement to learn what's valuable
- Suggestions should feel like helpful nudges, not nagging
- Requires ContextStore for goal/birthday awareness
- Consider quiet hours (no suggestions at night)
