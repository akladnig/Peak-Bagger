# 004-spec-change
This is an update to 004-prompt-spec.md, with changes to the csv file format, objectBox and calculations for centering the map and map extents.


- CSV headers (Series	Name	Parent	MGRS	eastingMin	eastingMax	northingMin	northingMax	mgrsMid	eastingMid	northingMid	TL	TR	BL	BR) to map directly to objectBox entity fields.
- The map centre is provided by  mgrsMid,	eastingMid &	northingMid	so calculations are no longer needed, only an objectBox lookup
- The top left, top right, bottom left and bottom right corners of the map are provided by TL, TR, Bl & BR. The format of each of these is [MGRS 100k square][easting5digit][northing5digit]
- All references in the spec 004-prompt-spec.md and 004-prompt-plan.md of Xmin, Xmax, Ymin, Ymax should be updated to eastingMin, eastingMax, northingMin & northingMax.
- 004-prompt-spec.md and 004-prompt-plan.md to be updated to reflect these spec changes.

