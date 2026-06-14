import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:slovenia_ortofoto_proxy/src/tile_handler.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final upstreamWmsUrl = Uri.parse(
    Platform.environment['UPSTREAM_WMS_URL'] ??
        'https://storitve.eprostor.gov.si/ows-pub-wms/wms',
  );

  final client = HttpUpstreamWmsClient(baseUrl: upstreamWmsUrl);
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(SloveniaOrtofotoTileHandler(upstreamClient: client).handle);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Serving Slovenia topo proxy on port ${server.port}');
}
