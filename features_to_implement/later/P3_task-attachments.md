# Task Attachments

**Priority:** P3
**View Area:** tasks_list
**Status:** NOT_STARTED

## Problem
Tasks have only title + plain text notes. Cannot attach reference photos, documents, or links for context.

## Requirements

### Must Have
- [ ] Attach images (camera or photo library)
- [ ] Attach URLs with link preview
- [ ] View attachments in task detail view
- [ ] Delete attachments
- [ ] Attachment storage in app documents directory
- [ ] Attachment count indicator on task row

### Should Have
- [ ] Attach files (PDF, documents) via Files picker
- [ ] Quick Look preview for attachments
- [ ] Image compression for storage efficiency
- [ ] Attachment size limits (warn on large files)
- [ ] Share attachment to other apps

## Attachment Data Model

### AttachmentEntity
| Field | Type | Purpose |
|-------|------|---------|
| id | UUID | Unique identifier |
| type | String | image, url, file |
| filename | String | Original or generated filename |
| url | String? | For URL attachments |
| localPath | String? | Path in documents directory |
| thumbnailPath | String? | Compressed preview image |
| createdAt | Date | When attached |
| task | TaskEntity | Parent relationship |

## Components Affected

### Files to Create
- `Models/AttachmentEntity.swift` - Attachment Core Data entity
- `Views/Tasks/AttachmentPickerView.swift` - Add attachment UI
- `Views/Tasks/AttachmentRowView.swift` - Attachment display
- `Views/Tasks/AttachmentPreviewView.swift` - Full preview (Quick Look)
- `Services/AttachmentService.swift` - Storage, retrieval, deletion

### Files to Modify
- `Tasky.xcdatamodeld` - Add AttachmentEntity, relationship
- `Views/Tasks/TaskDetailView.swift` - Attachments section
- `Views/Tasks/TaskRowView.swift` - Attachment count indicator

## Key Notes
- Store files in app's Documents directory (backed up)
- Generate thumbnails for images (performance)
- Handle storage cleanup when task deleted
- Consider storage quota/limits for free tier
- Core Data migration required
