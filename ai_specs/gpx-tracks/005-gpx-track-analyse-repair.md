# gpx track analyze and repair
Adds a new feature to analyze andrepair tracks with missing trackpoints or tracksegments.

## Background

In GPX files, track segments (<trkseg>) serve several purposes:
1. Logical grouping - Segments group related track points together, typically representing:
   - A continuous recording session (e.g., "start recording" → "pause/stop" → "resume")
   - Different activities within a single file (e.g., cycling vs. running)
   - Routes with breaks
2. Separation of time gaps - When you pause recording (or lose GPS signal), a new segment starts. This prevents false straight-line "connections" between points across time gaps.
3. Rendering differences - Many GPS apps/devices draw each segment with a different color or style, making it easy to distinguish separate recording sessions.
4. Metadata - Each segment can have its own metadata (time, name) separate from the overall track.

## Goal
This feature is used to analyze a gpx track on import:
- When there is a time gap between two track segments determine whether the time is due to:
   - a genuine pause of recording - in this case there should be little to no change of location.
   - a loss of signal or forgetting to restart recording - in this case there should be a significant difference in location.

- In the case where it is a loss of signal a new track segment should be inserted containing 2x <trkpt> the first a copy of the last <trkpt> of the first track segment and the second a copy of first <rtkpt>of the second track segment, coloured green and <type> tag added to say it is "interpolated". This is to be inserted in the original imported gpx track and saved to a new filed named gpxFileRepaired in the objectBox entity GpxTrack.
- If no repair is needed then the gpxFileRepaired should be set to an empty string.
- On Reset Track Data or Recalculate Track Statistics, if a repair is carried out, then gpxFileRepaired should be used to calculate the track Statistics.


