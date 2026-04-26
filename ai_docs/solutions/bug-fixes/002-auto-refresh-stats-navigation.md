---
title: Auto-refresh stats on screen navigation in Flutter
date: 2026-04-26
work_type: bugfix
tags: [flutter, state-management, navigation, lifecycle]
confidence: high
references: [lib/screens/settings_screen.dart]
---

## Summary

Fixed stats not refreshing on the Map Tile Cache screen when navigating back from the Map screen after viewing uncached tiles. Used multiple lifecycle hooks to ensure reliability.

## Reusable Insights

### What worked
1. **Manual refresh button** - Added to AppBar for explicit user control
2. **WidgetsBindingObserver** - Fires `didChangeAppLifecycleState` when app resumes (not useful for in-app navigation)
3. **RouteAware** - More reliable for screen re-entry detection within the same app

### Implementation pattern

```dart
class _TileCacheSettingsScreenState
    extends ConsumerState<Screen>
    with WidgetsBindingObserver
    implements RouteAware {
  
  static final RouteObserver<Route<dynamic>> _routeObserver =
      RouteObserver<Route<dynamic>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadAllStats(); // Fires when returning to this screen
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.unsubscribe(this);
    super.dispose();
  }
}
```

### Why multiple approaches
- `didChangeDependencies` uses cached context and doesn't fire reliably on back navigation
- `WidgetsBindingObserver.didChangeAppLifecycleState` only fires for app-level resume (switching apps), not screen navigation
- `RouteAware.didPopNext()` fires when another screen is popped and this screen becomes visible again

### Key lesson
Combine automatic refresh with manual refresh button for maximum reliability across different navigation patterns.

## Decisions

- Kept both `didChangeAppLifecycleState` (app resume) and `RouteAware` (screen navigation) for comprehensive coverage
- Manual refresh button provides escape hatch when automatic detection fails

## Pitfalls

- `RouteObserver` must be static (singleton) to work correctly
- Must implement all 4 RouteAware methods: `didPopNext`, `didPush`, `didPushNext`, `didPop`
- Type parameter `Route<dynamic>` causes lint warning about matching visible type name - acceptable tradeoff