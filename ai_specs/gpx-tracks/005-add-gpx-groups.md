
- Each schema item is to be grouped as described under the #### header, use a  separate entity which will allow a lookup of schema items e.g. "Distance" has distanceHint and distance fields. This is required for future dashboard views:
- this new entity should called gpxGroups and contain the following fields:

  - groupName - the name of the group e.g. "Distance"
  - groupHint - the hint text for the group e.g. "This is the distance hint"
  - groupFields - the fields in the group e.g. distance, distanceToPeak, distanceFromPeak

#### Distance Group
- the group hint: "This is the distance hint"

#### Elevation Group
- the group hint: "This is the elevation hint"

#### Speed Group
- the group hint: "This is the speed hint"
- fields to be added in the future

#### Duration Group
- the group hint: "This is the duration hint"
- fields to be added in the future

#### Climbs Group
- the group hint: "This is the climbs hint"
- fields to be added in the future
