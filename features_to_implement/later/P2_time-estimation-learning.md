# Time Estimation Learning

**Priority:** P2
**View Area:** ai_view
**Status:** NOT_STARTED

## Problem
User estimates task duration (30 min) but actually takes 90 min. App trusts estimates blindly. Planning becomes unrealistic. Users consistently underestimate without feedback.

## Requirements

### Must Have
- [ ] Track actual duration via focus timer sessions
- [ ] Compare estimated vs actual on completed tasks
- [ ] Calculate user's estimation accuracy ratio
- [ ] Store actualDuration on TaskEntity
- [ ] Show estimation accuracy in task detail (after completion)
- [ ] Warn when daily plan exceeds realistic capacity

### Should Have
- [ ] AI adjusts estimates based on user's history
- [ ] "Your 30min tasks typically take 75min" insight in analytics
- [ ] Per-category accuracy (if tags implemented)
- [ ] Suggestion: "Based on history, this might take 45min instead"
- [ ] Accuracy trend over time (improving or not)

## Accuracy Calculation

```
accuracyRatio = actualDuration / estimatedDuration

If ratio > 1.0: User underestimates
If ratio < 1.0: User overestimates
If ratio ≈ 1.0: User estimates well

Example:
- Estimated: 30 min
- Actual: 75 min
- Ratio: 2.5x (significant underestimation)
```

## Data Requirements

| Field | Source | Purpose |
|-------|--------|---------|
| estimatedDuration | User input | What user thinks it takes |
| actualDuration | Focus timer | What it actually took |
| accuracyRatio | Calculated | Comparison metric |

## Components Affected

### Files to Modify
- `Tasky.xcdatamodeld` - Add actualDuration field to TaskEntity
- `Models/TaskEntity+Extensions.swift` - Accuracy calculation helpers
- `Services/FocusService.swift` - Accumulate time to task on session end
- `Views/Tasks/TaskDetailView.swift` - Show accuracy after completion
- `Views/Progress/AnalyticsView.swift` - Estimation insights section
- `Services/AI/Tools/PlanDayTool.swift` - Apply accuracy factor to estimates

### Files to Create
- `Services/EstimationLearningService.swift` - Accuracy calculation, insights
- `Views/Progress/EstimationInsightsView.swift` - Accuracy visualization

## Key Notes
- Only works if user uses focus timer - can't measure otherwise
- Need sufficient data points before showing insights (10+ tasks minimum)
- Don't make user feel bad about underestimating - frame as helpful adjustment
- Consider: should AI silently adjust, or show "adjusted estimate"?
- Privacy: all calculations on-device
