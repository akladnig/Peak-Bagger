import 'dart:io';

import 'package:fvg_topo_proxy/src/tile_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final upstreamWmsUrl = Uri.parse(
    Platform.environment['UPSTREAM_WMS_URL'] ??
        'https://serviziogc.regione.fvg.it/geoserver/CARTOGRAFIA/wms',
  );

  final client = HttpUpstreamWmsClient(baseUrl: upstreamWmsUrl);
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(FvgTopoTileHandler(upstreamClient: client).handle);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Serving FVG topo proxy on port ${server.port}');
}
