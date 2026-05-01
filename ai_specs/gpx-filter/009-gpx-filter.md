# Goal
Filter the gpx track to allow accurate statistics to be calculated.
Save the filtered track to a new ObjectBox field: filteredTrack

This is adds gpx track filtering to 005-gpx-tracks-spec.md

file to review - required for schema updates:
- ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md

Based on research:

Hampel outlier filter + 1D median/low-pass smoothing for elevation
Recommended pipeline:
1. Drop impossible points
   - Remove track points that imply unrealistically high hiking speed or a big spatial jump.
2. Clean elevation with a Hampel filter
   - Use a sliding window of about 5 to 11 points. Allow choice of window size in settings.
   - Replace altitude spikes that deviate from the local median by more than 3 MADs
3. Smooth the remaining elevation
   - Apply a small median filter with option for Savitzky-Golay filter, allow choice of filter in settings.
   - Window size: 5 to 9 points for typical 1 Hz GPS tracks.  Allow choice of window size in settings.
4. Smooth lat/lon lightly
   - Use a small Kalman filter or very light moving average  allow choice of filter in settings.
   - Keep it conservative so trail bends are not distorted

Why this works for hiking:
- Hiking has slow motion with frequent stops
- GPS altitude is often the noisiest channel
- Hampel is good at removing spikes, which are the main problem in elevation profiles

