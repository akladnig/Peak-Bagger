---
title: Flutter Map Cursor Behavior Fix
date: 2026-04-08
work_type: bugfix
tags: [flutter, flutter_map, cursor, ui, macos]
confidence: high
references: [lib/screens/map_screen.dart, ai_specs/002-prompt-spec.md]
---

## Summary

Fixed mouse cursor behavior in the Flutter map component. The cursor now shows:
- **Open hand (grab)** - default on hover
- **Fist (grabbing)** - on pointer down (trackpad pressed)
- **Back to open hand** - on pointer up

Also fixed marker placement: location marker is only set on pointer up when it's a click (not a drag).

## Reusable Insights

### Cursor Implementation
- MouseRegion wraps FlutterMap to control cursor behavior
- Cursor only changes within the map region - overlays/FABs use default arrow
- Using `_isPointerDown` state variable with setState to trigger rebuild

```dart
MouseRegion(
  cursor: _isPointerDown
      ? SystemMouseCursors.grabbing
      : SystemMouseCursors.grab,
  child: FlutterMap(...)
)
```

### Pointer Handling
- Store `_pointerDownPosition` on pointer down
- On pointer up, check if movement > 5px to distinguish click from drag
- Only set selected location marker on click (not drag)

```dart
onPointerDown: (event, point) {
  setState(() {
    _isPointerDown = true;
    _pointerDownPosition = event.localPosition;
  });
},
onPointerUp: (event, point) {
  final moved = _pointerDownPosition != null &&
      (event.localPosition - _pointerDownPosition!).distance > 5;
  setState(() {
    _isPointerDown = false;
    _pointerDownPosition = null;
  });
  if (!moved) {
    ref.read(mapProvider.notifier).setSelectedLocation(point);
  }
},
```

### Key Decision
- Rejected gesture-based detection (onPositionChanged) as unreliable
- Adopted simpler approach: cursor changes on pointer down/up events regardless of actual drag
- This is more consistent with user expectations on trackpads

## Pitfalls
- flutter_map doesn't support custom cursors directly - requires MouseRegion wrapper
- onPointerHover fires continuously - avoid expensive operations in handler

## Spec Reference
- Updated `ai_specs/002-prompt-spec.md` line 78 with cursor behavior requirement