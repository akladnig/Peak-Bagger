# Map screen walking trails display
Adds a new feature to display walking trails on the map screen to make it easier to identify trails when planning routes.

Apply the source trail filter exactly:
- include `highway=footway` rows with `lengthMeters > 500` and `tagCount > 1`
- include all `highway=path` rows
- exclude `access=private`, `surface=concrete`, `surface=asphalt`, `surface=paved`, `surface=paving_stones`, `footway=sidewalk`, `foot=no`, and `route=mtb`
- do not include `highway=track` in this iteration

Then display the result on the map screen. This should probably sit just above the map layer and under all others.
The results should be displayed as a dashed black line sitting over a thicker green line. The styling for this should be set in theme.dart
Add a new FAB under "Show Tracks/Routes" named "Show Trails" using Icons.hikingOutlined, with a tooltip "Show Trails" 
