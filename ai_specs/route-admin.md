# Route ObjectBox Admin Updates 
Add Route-only edit and delete capability to ObjectBox Admin so maintainers can correct Peak metadata in place without leaving the admin browser.

1. Add a Route-only details-pane action row to the right-side details pane in `./lib/screens/objectbox_admin_screen_details.dart`, with a `visibilityOutlined` icon button titled `View Route on Main Map` placed to the left of the edit FAB, and the edit FAB placed to the left of the close icon. Clicking the map icon opens the main `MapScreen` and centers it on the Route location and  zooms to the route bounds - this should probably used the same shared helper as per the current track/route extents zoom in the map screen.
3. Render Route fields in edit mode as inline form controls, not a modal dialog while allowing the remaining Route fields to be edited inline.
7. Add a Route-only actions column in `./lib/screens/objectbox_admin_screen_table.dart` with a per-row delete icon, pinned for Route data rows only, and use the same confirm-dialog pattern used by Route Lists, including stable cancel/confirm dialog keys.
   The delete confirmation dialog must use title `Delete Route?` and message `This will permanently delete the <route name>. Do you want to proceed?`.
9. Preserve current browse/search/sort/detail-pane behavior for existing read-only admin flows.

10. After a successful Route save, show `showSingleActionDialog` with title `Update Successful` and content text `<route name> updated.` using the saved Route name.
13. Preserve row selection by Route primary key across save refreshes, and after delete keep the current selection if the selected Route still exists or clear it only when the deleted Route was the selected row.
- only display a max of 5 lines with scroll behaviour implemented or using a shared helper as per gpxFile in the GpxTrack entity.
