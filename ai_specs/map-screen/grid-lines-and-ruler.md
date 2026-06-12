# 1km Grid lines and Distance Ruler
Creates thin 1km grid lines and a Distance Ruler to enhance the current zoom display
This is to be implemented in 2 phases with the first phase completed before moving to the second phase

## Phase 1 - Grid Lines
The Show Map Grid FAB is to be updated to optionally show a 1 km grid.
- A grid with borderStrokeWidth =  MapConstants.map1kmGridBorderWidth is to be drawn at every 1km MGRS easting and northing
- add a new constant MapConstants.mapGridBorderWidth = 2 and update map_screenlayers:81, and tasmap_outline_layer:29 to use this constant.
- add a new constant MapConstants.map1kmGridBorderWidth = 1 which is the StrokeWidth to be used for the 1km grid.
- The borderColor=Colors.blue is to be defined in theme.dart as mapGridColour. Existing borderColor in  map_screenlayers and  tasmap_outline_layer is to updated to use this.
- The current Show Map Grid FAB is to be updated as follows:
  1. default is for no grid to be shown and current tooltip of "Show Map Grid" to remain as is.
  2. On clicking the FAB the Map Grid is shown and the tooltip changes to "Show Map and 1 km Grid"
  3. On clicking the FAB the Map Grid and 1 km grid are shown and the tooltip changes to "Hide Grids"
  4. On clicking the FAB both grids are hidden and the state machine goes back to step 1.

## Phase 2 - Distance Ruler
The existing zoom display is to be updated to show a distance ruler. 
A sample of the intended graphic is shown in ai_specs/ruler.png
The 1 km display should be adjusted from 1 m all the way to 100 km. The number should step in interval of 1, 2, 3, 5 e.g. 10 m, 20 m, 30 m, 50 m, 100m etc. This means that the width of the box will need adjust as the scale changes.
The zoom is still to be displayed, but to be right aligned in the ruler box.
All associated constants and styles are to placed in constants.dart and theme.dart

