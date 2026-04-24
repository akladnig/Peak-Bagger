# Adds Edit Peak List and add new peak functionality
Updates 011-.*spec.md files to add an Edit Peak List and Add a new peak features along with some UI tweaks

## Update UI for Peak List Details
1. Add a new column Ascents before the Points column. This column will show the number of times a peak has been climbed.
2. Add the same sort functionality as the Ascent Date Column i.e. blanks remain at the bottom.
3. If peak has not been climbed leave the content blank
4. Pin the header row to the top.
5. On selection of a peak, the blue circle should appear on the top layer
6. On selection of a peak display a dialogue box showing:
  a An Edit Icon and
  b Delete Icon at the top right of the dialogue box.
  c Name of the Peak
  d Height of the peak
  e How many points the peak is worth
  f MGRS coordinates with the lat/long on the same line
  g The name of map in which the peak is located, as a clickable link that opens Map Screen at that map's extents
  h A list of dates the peak was climbed, with the year included
  i a link to the gpxFile

As a layout guide, place the items as per the following example:
      edit add
Mount Wellington
Elevation: 1545m
Points: 1

Location: 55G EN 19400 507000 (-42.89602, 147.23731)
Map: Wellington, TK08

| Ascent Date | GPX |
|-------------|-----|
| Mon, Mar 18 2026 | link|
| Wed, Mar 4 2025 | link|


### Add New Peak to List
- Add a new button to the top right of Peak List Details:
  - label: "Add New Peak" - use AddCircleOutlineOutlinedIcon. To be placed at top right.

- When this icon is clicked a searchable dropdown box the same as Search Peaks in the Map Screen will be displayed allowing selection of a peak which will be added to the selected peak list.
- Also add an integer selector from 0 to 10 to the right of the search dropdown to allow entry of Points

### Edit Peak List
- Clicking the Edit icon brings in the dialog box allows only the following fields to be edited:
  - Points
