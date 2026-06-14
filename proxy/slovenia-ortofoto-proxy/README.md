# Slovenia Ortofoto Proxy

Standalone XYZ tile proxy for Peak Bagger's Slovenia ortho basemap.

- Committed app URL: `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`
- Upstream WMS: `https://storitve.eprostor.gov.si/ows-pub-wms/wms`
- Upstream layer: `SI.GURS.ZPDZ:DOF5`

## Local run

```bash
dart pub get
PORT=8080 dart run bin/server.dart
```

Optional upstream override:

```bash
UPSTREAM_WMS_URL=https://storitve.eprostor.gov.si/ows-pub-wms/wms dart run bin/server.dart
```
