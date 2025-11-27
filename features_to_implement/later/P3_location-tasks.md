# Location-Based Tasks

**Priority:** P3
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Tasks have time but not place. "Buy milk" cannot trigger near grocery store. Errand batching by location is impossible.

## Requirements

### Must Have
- [ ] Add optional location to task (latitude, longitude, radius)
- [ ] Location picker with search (MapKit)
- [ ] Geofence notification when entering location radius
- [ ] Location permission handling (when in use → always for geofencing)
- [ ] Show location indicator on task row
- [ ] View task location on map in detail view

### Should Have
- [ ] "Nearby tasks" filtered view
- [ ] AI: "What can I do while I'm out?"
- [ ] Errand batching suggestions (group by area)
- [ ] Save frequent locations (Home, Work, Gym)
- [ ] Location-based smart list

## Location Data Model

| Field | Type | Purpose |
|-------|------|---------|
| locationName | String? | "Whole Foods", "Home" |
| latitude | Double? | Coordinate |
| longitude | Double? | Coordinate |
| radius | Double? | Trigger radius in meters (default 100m) |

## Components Affected

### Files to Modify
- `Tasky.xcdatamodeld` - Add location fields to TaskEntity
- `Views/Tasks/TaskDetailView.swift` - Location picker section
- `Views/Tasks/TaskRowView.swift` - Location indicator
- `Info.plist` - Location usage descriptions

### Files to Create
- `Views/Tasks/LocationPickerView.swift` - Map-based location selection
- `Views/Tasks/NearbyTasksView.swift` - Location-filtered task list
- `Services/LocationService.swift` - Geofencing, location monitoring
- `Services/GeofenceNotificationService.swift` - Location-triggered notifications

## Key Notes
- Geofencing requires "Always" location permission for background triggers
- Battery impact: limit to 20 active geofences (iOS limit)
- Handle permission denied gracefully (location features disabled)
- Consider privacy: location data stays on-device only
