// @name Tassy paths and footways

[out:json];
way["highway"="footway"]({{bbox}})->.all_footways;
way["highway"="path"]({{bbox}})->.all_paths;
way["highway"="track"]({{bbox}})->.all_tracks;
// Filter the paths that are strictly longer than 1000 meters
way.all_footways(if: length() > 500)->.long_footways;
way.long_footways(if: count_tags() > 1)->.footways_with_no_tags;
(
  (
    way.footways_with_no_tags;
    way.all_paths;
    /*way.all_tracks;*/
  );
  - (
    way["access"="private"]({{bbox}});
    way["surface"="concrete"]({{bbox}});
    way["surface"="asphalt"]({{bbox}});
    way["surface"="paved"]({{bbox}});
    way["surface"="paving_stones"]({{bbox}});
    way["footway"="sidewalk"]({{bbox}});
    way["foot"="no"]({{bbox}});
    way["route"="mtb"]({{bbox}});
  );
);
out body;
>;
out skel qt;
