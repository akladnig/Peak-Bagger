# Peak Lists enhancements
## Goal
Adds a number of enhancements to Peak Lists

## Data Import
- On import of a csv file if either a lat/long pair or Zone/Easting/Northing is missing, then calculate the values of the missing data from the provided data.
- If a Height datum is missing, set the value to 0 and log a warning in import.log with the peak name.

## UI updates
Adds a summary view of the available lists.

The left side of the screen will display a table of the peak lists (refer ### Peak List Table) - initially set to 40% of available screen width.
The right side will display details of the selected peak list (refer ### Peak List Details)- initially set to 60% of available screen width.
There should be a vertical divider line between the two to allow the user to dynamically change the width. 

The Peak List is selected by clicking on a row in the table, and displayed in the Peak List Details

### Peak List Table
- The table will have the following column headers:
  - List
  - Total Peaks
  - Climbed
  - Percentage
  - Unclimbed

- The List header is name of the list from the PeakList entity
- The Total Peaks header is a count of the total number of peaks in the selected List.
- Climbed header is a placeholder, for now set to 0
- Percentage header is a placeholder, for now set to 0
- Unclimbed header is a placeholder, for now set to 0

After the Date column add an actions column with a single icon:

- Delete Icon: DeleteForeverIcon from '@mui/icons-material/DeleteForever'; use label text of "Delete List"

For each icon add a tooltip using lib/widgets/left_tooltip_fab.dart and the provided label text

### Peak List Details
- Shows a title at the top which is the peak name.
- Underneath the title shows a line of text:
  "PeakName is your most recent, climbed on Date. You have now climbed Climbed out of TotalPeaks, or Percentage."

Underneath this shows a split view of:
- left:  Shows the list of peaks in the List as a table with the following columns:
  - Peak Name
  - Elevation
  - Ascent Date
- right: Shows a mini map of all peaks in the list, using the same icon strategy as the map_screen, Unclimbed Peaks use peak_marker.svg, climbed peaks use peak_marker_ticked.svg

For now set the width of the list to 30% of this available space.

Future: open mini-map in full screen or navigate to map_screen.
Future: add edit list icon and actions.
<!-- - Edit Icon: EditIcon from '@mui/icons-material/Edit'; use label text of "Edit Details" -->

## Delete Icon
- opens a confirmation dialog using the showDangerConfirmDialog 

- title text: "Delete Peak List?"
- message text: "This will permanently delete the nameOfListSelected. Do you want to proceed"
