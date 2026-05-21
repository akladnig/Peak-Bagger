# Create Route Enhancements

- On App startup the local Json is loaded every time, bundle this with the app so it does not need to be loaded.
- Remove the overpass fallback, only load from local Json.
- Add a "Refresh Track Data" button in the Settings Screen so that it uses a pattern similar to "Refresh Peak Data" which then loads data from overpass adn saves it to highway.json. The querry should be as per the existing overpass query.

