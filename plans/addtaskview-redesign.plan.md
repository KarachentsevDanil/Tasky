# AddTaskView Redesign Plan - Things 3 Style

## Overview

Transform the current form-heavy AddTaskView into a clean, minimal interface inspired by Things 3. Focus on reducing cognitive load, removing visual clutter, and creating a delightful task creation experience.

## Current Problems

| Problem | Severity | Things 3 Solution |
|---------|----------|-------------------|
| Double navigation (back + Cancel) | High | Single back button |
| Heavy section headers ("Title", "Notes", etc.) | High | No headers, contextual icons |
| Toggle-first pattern for dates/time | High | Tappable rows with inline expansion |
| TextEditor for notes too prominent | Medium | Collapsible text field |
| System Form styling (cards, dividers) | High | Flat list with subtle separators |
| Unnecessary footer text | Medium | Remove entirely |
| Too many visible options | Medium | Progressive disclosure |

## Design Principles (Things 3 Style)

1. **Keyboard-first** - Title field auto-focused, ready to type
2. **Minimal chrome** - No unnecessary headers, labels, or containers
3. **Inline expansion** - Tap to reveal options, not toggle + configure
4. **Subtle icons** - SF Symbols at appropriate weight, muted colors
5. **Breathing room** - Generous spacing, not cramped
6. **Smart defaults** - Today's date pre-selected, sensible starting state
7. **Gestural** - Swipe to dismiss, tap anywhere to collapse

## Implementation Plan

### Phase 1: Structure Cleanup

#### 1.1 Remove NavigationStack wrapper
- AddTaskView is presented via navigation, parent provides NavigationStack
- Remove inner NavigationStack to avoid double navigation bar

#### 1.2 Simplify toolbar
- Keep only "Cancel" (leading) and "Add" (trailing)
- Remove back arrow redundancy
- "Add" should be accent color when enabled, gray when disabled

#### 1.3 Replace Form with ScrollView + VStack
- Form adds unwanted card styling
- Use plain ScrollView for full control over appearance

### Phase 2: Input Fields Redesign

#### 2.1 Title field (Things 3 style)
```
┌─────────────────────────────────────────┐
│ What do you want to do?                 │  ← Large, friendly placeholder
└─────────────────────────────────────────┘
```
- No "Title" header
- Large placeholder text: "What do you want to do?"
- Auto-focus on appear
- Clean TextField, no border until focused
- `.font(.title3)` for prominence

#### 2.2 Notes field (collapsible)
```
Before tap:
┌─────────────────────────────────────────┐
│ 📝  Add notes                        ＞ │
└─────────────────────────────────────────┘

After tap (expanded):
┌─────────────────────────────────────────┐
│ 📝  Notes                               │
├─────────────────────────────────────────┤
│                                         │
│ Type your notes here...                 │
│                                         │
└─────────────────────────────────────────┘
```
- Collapsed by default (just a row)
- Expands to TextEditor on tap
- Auto-focus when expanded
- Collapse when empty and tapped outside

### Phase 3: Date & Time Redesign

#### 3.1 Unified Date Row
```
┌─────────────────────────────────────────┐
│ 📅  Today                            ＞ │  ← Tappable, shows current selection
└─────────────────────────────────────────┘

Expanded (inline):
┌─────────────────────────────────────────┐
│ 📅  Today                            ✓  │
├─────────────────────────────────────────┤
│  [Today]  [Tomorrow]  [+3 Days]  [Pick] │  ← Quick chips
├─────────────────────────────────────────┤
│         (Graphical date picker)         │  ← Only if "Pick" tapped
└─────────────────────────────────────────┘
```
- Single row shows current date
- Tap to expand inline (not sheet)
- Quick chips: Today, Tomorrow, +3 Days, Pick Date
- "No date" option to clear
- Smooth spring animation

#### 3.2 Time Slot Row
```
┌─────────────────────────────────────────┐
│ ⏰  Add time                         ＞ │
└─────────────────────────────────────────┘

Expanded:
┌─────────────────────────────────────────┐
│ ⏰  9:00 AM - 10:00 AM               ✕  │  ← X to clear time
├─────────────────────────────────────────┤
│  [15m] [30m] [1h] [2h] [Custom]         │  ← Duration chips
├─────────────────────────────────────────┤
│  Start: [==9:00 AM==]                   │  ← Compact time pickers
│  End:   [==10:00 AM==]                  │
└─────────────────────────────────────────┘
```
- Shows "Add time" when no time set
- Shows formatted time range when set
- Duration presets for quick selection
- Clear button (X) to remove time

### Phase 4: Additional Options

#### 4.1 Repeat Row
```
┌─────────────────────────────────────────┐
│ 🔁  No repeat                        ＞ │
└─────────────────────────────────────────┘

Expanded:
┌─────────────────────────────────────────┐
│ 🔁  Weekly                           ✕  │
├─────────────────────────────────────────┤
│  [Daily] [Weekly] [Monthly]             │
├─────────────────────────────────────────┤
│  [M] [T] [W] [T] [F] [S] [S]           │  ← Day selector (if weekly)
└─────────────────────────────────────────┘
```

#### 4.2 Priority Row
```
┌─────────────────────────────────────────┐
│ 🚩  No priority                      ＞ │
└─────────────────────────────────────────┘

Expanded:
┌─────────────────────────────────────────┐
│ 🚩  High                             ✕  │
├─────────────────────────────────────────┤
│  [None] [Low] [Medium] [High]           │  ← Priority chips with colors
└─────────────────────────────────────────┘
```
- Flag icon changes color based on selection
- Chips show priority colors

#### 4.3 List Row
```
┌─────────────────────────────────────────┐
│ 📁  Inbox                            ＞ │
└─────────────────────────────────────────┘

Expanded:
┌─────────────────────────────────────────┐
│ 📁  Work                             ✕  │
├─────────────────────────────────────────┤
│  ○ Inbox                                │
│  ● Work                                 │  ← Selected
│  ○ Personal                             │
│  ○ Shopping                             │
└─────────────────────────────────────────┘
```

### Phase 5: Visual Polish

#### 5.1 Row Component Design
Create reusable `ExpandableOptionRow`:
```swift
struct ExpandableOptionRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    let isExpanded: Binding<Bool>
    let canClear: Bool
    let onClear: (() -> Void)?
    @ViewBuilder let expandedContent: () -> Content
}
```

#### 5.2 Colors & Spacing
- Icon color: `.secondary` by default, accent when has value
- Row height: 52pt (comfortable tap target)
- Horizontal padding: 20pt
- Vertical spacing between rows: 1pt (hairline separator)
- Expanded content padding: 16pt

#### 5.3 Animations
- Row expansion: `.spring(response: 0.35, dampingFraction: 0.8)`
- Chevron rotation: 90° when expanded
- Content fade: `.opacity` combined with `.move(edge: .top)`

#### 5.4 Typography
- Row label: `.body` (17pt)
- Row value: `.body` with `.secondary` color
- Section hint: `.caption` with `.tertiary` color
- Title field: `.title3` (20pt)

### Phase 6: Interaction Refinements

#### 6.1 Keyboard handling
- Auto-focus title on appear (0.5s delay)
- "Done" on keyboard dismisses keyboard
- Return key moves to notes (if expanded)

#### 6.2 Haptics
- Row tap: `.selectionChanged()`
- Option selection: `.lightImpact()`
- Clear action: `.lightImpact()`
- Task created: `.success()`

#### 6.3 Accessibility
- All rows have proper labels
- Expanded state announced
- VoiceOver hints for actions

## File Changes

### Modified Files
1. `Tasky/Features/Tasks/Views/Screens/AddTaskView.swift` - Complete rewrite

### New Files
2. `Tasky/Features/Tasks/Views/Components/ExpandableOptionRow.swift` - Reusable row component
3. `Tasky/Features/Tasks/Views/Components/QuickDateSelector.swift` - Date chips + picker
4. `Tasky/Features/Tasks/Views/Components/DurationSelector.swift` - Time duration chips
5. `Tasky/Features/Tasks/Views/Components/WeekdaySelector.swift` - Day of week picker (for recurrence)

## Visual Mockup

```
┌────────────────────────────────────────┐
│ Cancel         New Task           Add  │
├────────────────────────────────────────┤
│                                        │
│  What do you want to do?               │  ← Title (large, focused)
│  ─────────────────────────────────     │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 📝  Add notes                  ＞│  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 📅  Today                      ＞│  │  ← Blue icon (has value)
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ ⏰  Add time                   ＞│  │  ← Gray icon (no value)
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🔁  No repeat                  ＞│  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 🚩  No priority                ＞│  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 📁  Inbox                      ＞│  │
│  └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

## Success Metrics

- **Reduced visual elements**: From ~15 visible controls to ~7
- **Faster task creation**: Title → Add in 2 taps (vs 4+ currently)
- **Cleaner appearance**: No section headers, no toggle switches
- **Consistent with QuickAddSheet**: Similar chip-based selection patterns
- **iOS native feel**: Follows HIG, feels like system app

## Implementation Order

1. Create `ExpandableOptionRow` component
2. Create `QuickDateSelector` component
3. Create `DurationSelector` component
4. Create `WeekdaySelector` component
5. Rewrite `AddTaskView` using new components
6. Add animations and haptics
7. Test accessibility
8. Polish and refinements

## Estimated Scope

- Components: 4 new files (~400 lines total)
- AddTaskView rewrite: ~300 lines (down from 274, but cleaner)
- Total: ~700 lines of focused, reusable code
