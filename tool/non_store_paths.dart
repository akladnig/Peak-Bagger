import 'dart:io';

import 'package:peak_bagger/services/mapping_tool_resolver.dart';

/// Store-isolated shell adapters validate external/report operands here before
/// using them. This command cannot grant Mapping read or write capabilities.
Future<void> main(List<String> paths) async {
  try {
    for (final path in paths) {
      await requireNonMappingPath(path);
    }
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
