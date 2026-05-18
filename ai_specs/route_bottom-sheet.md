# Create Route Bottom Sheet
## Goal
On clicking the Create Route button, a sheet will slide up from the bottom to display the following:
- A Header Bar
- A placeholder elevation graph - just a blank box for now, which will be populated in the future.

This sheet is a placeholder sheet only for now with placeholder data values.

The height of the sheet will be set via a new constant in constants.dart named RouteConstants.sheetHeight and initiially set to 320px.

## Header
The Header will contain three groups from left to right:
- Distance/Elevation Group (Start of row)
- Route Editing Group (Centre of row)
- Actions Group (End of row)

###  Distance/Elevation Group
From left to right:
- Distance in km to single decimal point (use a placeholder value of 12.3 km) formatted as xx.x km, where xx.x is bold
- Ascent in m (use a placeholder value of 315 m) formatted with Icons.arrowupward yyy, where yyy is bold
- Descent in m (use a placeholder value of 234 m)  formatted with Icons.arrowdownward yyy, where yyy is bold

### Route Editing Group
From left to right:
- Text: "Routing Mode: "
- Snap to Trail button - currently no-op, changes to green on selection
- Straight Line button - currently no-op, changes to green on selection
- Text Entry Box - Route Name
The buttons are mutually exclusive, clicking on one selects and deselects the other.
Default is Snap to Trail

### Actions Group
From left to right:
- Cancel Button - Closes the bottom sheet
- Save Button - Closes the bottom sheet (save functionality to be implemented in the future)

## Existing Map FAB Groups
Disable the following FAB groups:
- Tools
- Loc

Allow View Group FABs to maintain current functionality

## Side Menu
Clicking on the side menu surfaces a showDangerConfirmDialog with:
title: "Warning"
message: "Switching sidebars right now will lose any unsaved changes to your data. Are you sure you want to continue?"
- confirmLabel: Continue

On Continue close the sheet and navigate to the selected side menu item.

## Create Route FAB action
- On clicking Create Route FAB clear the Centre Marker and any selected tracks. Close any pop-ups or drawers.

## Shortcut Keys
Disable all shortcut keys except for:
- Zoom keys -, +, <, >, _, =, ",", "."
- Navigation keys h, j, k, l
- Tracks - t
- Basemaps - b

## UI
- Allow the user to click on the map and place green markers - use Icons.Adjust
