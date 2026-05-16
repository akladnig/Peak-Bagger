# Elevation Card
## Goal
Create the content for the Elevation Card

## Content
Refer to ai_specs/dashbaord/elevation.png for a sample elevation screenshot.
Refer to ai_specs/dashbaord/bags.png for a sample peaks bagged screenshot.

The screenshot is a derived summary card: monthly total ascent over a time window, not a raw track detail view.

Create a number of buckets, not just a month bucket as shown in the screenshot. The buckets should be:
  - day bucket
  - week bucket
  - month bucket
  - 3 month bucket
  - 6 month bucket
  - annual bucket

Each bucket is selectable by a dropdown except for the day bucket.
The Time Period dropdown in the screen shot currently shows "Last 12 Months". This should be updated to allow a dropdown allowing choice of:
- Week (shows day buckets as Mon, Tue, etc.)
- Month (shows day buckets as 1, 2, 3 etc. )
- Last 3 & 6 Months (show week buckets grouped by month e.g. Jan, Feb, etc. so that there may be 4 and a bit bars per month)
- Last 12 Months (shows month buckets as Jan, Feb, Mar etc.)
- All Time (shows year buckets as 2024, 2025 etc.)

Show all time periods as a moving window - e.g. Week shows the last 7 days from today.
All time windows to be scrollable horizontally.

Allow the display to be either a column view as per elevation.png or smoothed line as per bags.png. Add a FAB to toggle the display at the top right of the graph
Hovering over a column should highlight the column and surface a popup showing the column name and elevation total for that column. The column name should be on the top row and the elevation in metres in the second row.
The title row should include Time Period Dropdown, the total for that period and previous/next arrows, so this replaces the title row in the jpg.

## Notes from previous research which needs to be validated based on updated requirements above:
What I’d do:
- Use GpxTrack.trackDate as the month bucket key. It’s already normalized to local date in lib/services/gpx_importer.dart:341-344.
- Use GpxTrack.ascent as the value to sum. That field is already persisted in lib/models/gpx_track.dart:35-42.
- Build a small read-only summary layer that watches the current track list and computes buckets like YYYY-MM -> total ascent.
- Render that in a new ElevationCard widget, then wire it into DashboardScreen for the elevation card ID in lib/providers/dashboard_layout_provider.dart:18-25 and lib/screens/dashboard_screen.dart:44-55.

On persistence:
- I would not add a new ObjectBox entity for this summary right now.
- This is fully derivable from source tracks, and the data set is probably small enough that recomputing on dashboard rebuild is fine.
- A summary entity adds upkeep: updates on import/delete/replace, stale-cache risk, and migration work.
- Only persist summaries if you later need large-scale analytics, snapshot history, or expensive queries across lots of records.

One caveat:
- The screenshot’s Hike legend implies a category/tag dimension, but the current model does not have activity type metadata. If you want multiple series later, that needs a real source field, not just a cached summary.


### Additional notes discussing above
- A hike legend is not required, there is no need for a category/tag dimension
- Additional analytics will be required in the future for a distance card.  
