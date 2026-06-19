# FVG Topo Proxy

Standalone XYZ tile proxy for Peak Bagger's Friuli Venezia Giulia topo basemap.

- Committed app URL: `https://tiles.peakbagger.com/fvg-topo/{z}/{x}/{y}.png`
- Upstream WMS: `https://serviziogc.regione.fvg.it/geoserver/CARTOGRAFIA/wms`
- Upstream layers by zoom:
  - `z1-z12`: `IRDAT:CRN25KColore`
  - `z13+`: `IRDAT:CTRN5KColore`
- Local debug app URL defaults to `http://127.0.0.1:8081/fvg-topo/{z}/{x}/{y}.png`.
- Override with `--dart-define=FVG_TOPO_TILE_URL=http://<host>:8081/fvg-topo/{z}/{x}/{y}.png` if needed.

## Local run

```bash
dart pub get
PORT=8081 dart run bin/server.dart
```

Optional upstream override:

```bash
UPSTREAM_WMS_URL=https://serviziogc.regione.fvg.it/geoserver/CARTOGRAFIA/wms dart run bin/server.dart
```
