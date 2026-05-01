# ObjectBox Peak Admin updates
## Goal add additional functionality to the ObjectBox Admin Peak entity
- When a peak is selected and details are shown to the right add an edit FAB to the left of close icon.
- The edit FAB will then allow editing of the fields in the details shown below, apart from the id field which is not to be edited, and surface a submit button at the bottom of the detials list.
- if only latitude and longitude are entered, then gridZoneDesignator, mgrs100kId, easting and northing are to calculated. The converse is true if latitude and longitude are blank.
- surface a dialogue on successful submission using the  showSingleActionDialog with the message "name updated." where name is the name of the peak. the title should be "Update Successful"
- validate the entered updates and if the entered location is not within Tasmania as detailed by the bounds in /lib/models/geo_areas.dart surface an error message "Entered location is not with Tasmania."
- If the latitude is not a valid number surface an error message "Latitude must be a number between -90.0 and 90.0"
- If the longitude is not a valid number surface an error message "Latitude must be a number between -180.0 and 180.0"
- If the easting is not a 1-5 digit number surface an error warning with message "easting must be a 1-5 digit number"
- If the northing are not a 1-5 digit number surface an error warning with message "northing must be a 1-5 digit number"
- If mgrs100kid is not a two letter string 
surface an error warning with message "The MGRS 100km identifier must be exactly two letter"
- Do not allow changes to gridZoneDesignator
- add an actions column with a delete icon as per the peak lists screen including the same dialog messaging.
