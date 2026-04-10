# Phase 4
## Goal
Adds a database of Tasmanian maps. This will be used in the goto location search.

When searching via mgrs coordinates the grid zone designator (GZD) and two letter 100,000 metre square is required along with the numerical location. For Tasmania the GZD is 55G.

The 2 letter 100k square is mapped directly to a map name and series.

The goto location search needs to be updated so that  50k map names can ne used instead. An example search is "Wellington 194507" which is the full mgrs coordinate 55GEN1940050700.

Add an ObjectDatabase or store to the existing ObjectBox to store the 50kTasmap.

On launch of app for the first time import data from assets/tasmap50k.csv.
Map the databse schema field name to the csv column name as per the schema below.
The csv columns are shown in brackets in the database schema below:

Map Database Schema:
- 50kMapId
- 50kSeries (Column 1)
- 50kName (Column 2)
- 100kParentSeries  (Column 3)
- mgrs100kId  (Column 4)
- eastingMin  (Column 5)
- eastingMax  (Column 6)
- northingMin  (Column 7)
- northingMax  (Column 8)

Add a popup dialog box that displays the map name of the location clicked on in the map. If a peak is clicked, also display the peak name and elevation.

