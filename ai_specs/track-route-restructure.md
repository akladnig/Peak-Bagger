d:cd Track and Route folder restructure
When importing routes and tracks change the default save folders based on country and Region.
Tracks and routes now need to be saved to the folder as per the structure below, determining the location of the track/route based on the location of the very first track or route point, as some routes/tracks may cross country or regional boundaries.

The folder structure is:
  - ~/Documents/Bushwalking/Tracks/Country/Region
  - ~/Documents/Bushwalking/Routes/Country/Region

Where Country is one of:
- Australia
- Italy
- Slovenia
- Croatia

Where Region is one of (grouped by Country) and defined by the polygons in assets/polygons:
- Australia:
	- NSW (new-south-wales.poly)
	- Tasmania (tasmania.poly)
- Italy:
	- nord-est (italy-nord-est.poly)
	- nord-ovest (italy-nord-ovest.poly)
- Slovenia: (slovenia.poly) 
	- NONE 
- Croatia (croatia.poly)
	- NONE

If region is NONE, then there is no region subfolder, just the parent country.


