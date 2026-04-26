# Flutter Map Tile Caching
## Goal
Implement caching to improve user experience by reducing network waiting times, and to prepare for no-Internet situations, caching should be long term.
The preferred option is bulk downloading to prepare for known no-Internet situations by downloading map tiles, then serving these from local storage.
Use the flutter_map plugin: flutter_map_tile_caching: ^10.1.1 to implement this.
Local storage should be visible via MacOS finder
