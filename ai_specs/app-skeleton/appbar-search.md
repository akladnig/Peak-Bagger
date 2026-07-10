# Add Search to the AppBar
Adds Search functionality to the AppBar

- Add a Search Button to the middle of the AppBar:
  - Shows Icons.search on the left followed by the text "Search Cmd+F" - use the macOS Command symbol for Cmd+
  - Set the border colour to outlineVariant
- On clicking on the Search Button or using the keyboard shortcut Cmd+F surface a popup and set focus to the Search Text Field.

## Popup
- Add a Search Text Field to the top left of the popup with the text "Search"
- Under this add a thinDivider (theme.dart)
- Under the thinDivider add the following icon + text buttons:
  - Icons.language All
  - Icons.landscape Peaks
  - Icons.hiking Trails
  - Icons.forest Natural
  - Icons.directions_car Roads 
  - Icons.map Maps
  Add a vertical divider before the last two buttons
  - Icons.filter_list Filter
  - Icons.sort Sort

- Under the buttons add a header "Results"
- Display a scrollable list of results:
  - On the left display the icon matching the result type. Then the summary details associated with the result.
- All of these buttons use SelectedButtonThemeData for the button styling

## Popup Buttons
These buttons are mutually exclusive and by default All is selected:
  - all
  - peaks
  - Trails
  - Natural
  - Roads 
  - Maps
Clicking on a button selects it and filters the results.

## Summary Details
This specifies the details to be shown for each result type
### Peaks
- Peak Name, Peak Height, Map Name if available, Region
- obtain from objectbox
### Trails
- Trail Type, Trail Name, Trail Length Height, Map Name if available, Region
- Trail Type can be one of Track, Route or Trail
- Track and route can be obtained from objectBox
### Natural
- Place holder for now, keep disabled
### Roads
- Place holder for now, keep disabled
### Maps
- Map name, Region

### Filter Button
- By default filter to none
- Add the following filter options:
  - Filter by Region which shows a list of regions as defined in region_manifest.json

### Sort Button
- By default sort ascending by name
- Add the following options:
  - Sort by name ascending
  - Sort by name descending

