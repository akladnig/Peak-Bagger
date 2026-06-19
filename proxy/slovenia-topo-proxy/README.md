# Slovenia Topo Proxy

Standalone XYZ tile proxy for Peak Bagger's Slovenia topo basemap.

- Committed app URL: `https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`
- Upstream WMS: `https://storitve.eprostor.gov.si/ows-pub-wms/wms`
- Upstream layers by zoom:
  - `z1-z8`: `SI.GURS.DK:DPK1000`
  - `z9`: `SI.GURS.DK:DPK750`
  - `z10`: `SI.GURS.DK:DPK500`
  - `z11-z12`: `SI.GURS.DK:DPK250`
  - `z13+`: `SI.GURS.DK:DTK50`
- Local debug app URL defaults to `http://127.0.0.1:8080/slovenia-topo/{z}/{x}/{y}.png`.
- Override with `--dart-define=SLOVENIA_TOPO_TILE_URL=http://<host>:8080/slovenia-topo/{z}/{x}/{y}.png` if needed.

## Local run

```bash
dart pub get
PORT=8080 dart run bin/server.dart
```

Optional upstream override:

```bash
UPSTREAM_WMS_URL=https://storitve.eprostor.gov.si/ows-pub-wms/wms dart run bin/server.dart
```

## Local production hostname setup

For a macOS local setup that keeps the app pointed at
`https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`, see:

- `local-production/README.md`
