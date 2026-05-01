# Peaks Bagged
Adds a new objectBox entity to store the Peaks that have been bagged aka ticked.

Name the entity PeaksBagged with the following fields:
- baggedId
- PeakId - uses the osmId of the Peaks entity
- gpxId - uses the gpxTrackId of GpxTrack
- Date - date of the ascent uses trackDate of GpxTrack

On Reset Track Data or Recalculate Track Statistics examine the GpxTrack entity and for every row for which the peaks fields contains data, extract the osmIds from the peaks field and create a new row in PeaksBagged.

On Reset Track Data also reset the baggedId to 1.

