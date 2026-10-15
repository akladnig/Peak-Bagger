import 'dart:io';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';
import 'mapping_tool_support.dart';

/// Exact registered manual promotion. A transaction supplies the lifetime lease;
/// this command cannot widen a target through overrides or a directory output.
Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 4 ||
        arguments[0] != '--target' ||
        arguments[2] != '--source') {
      throw ArgumentError(
        'Usage: mapping_source_promote --target STORE_RELATIVE_PATH --source NON_STORE_FILE',
      );
    }
    await promoteMappingSource(
      await openMappingTool('mapping-maintenance-promote'),
      target: arguments[1],
      source: arguments[3],
    );
  } on Object catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}

Future<void> promoteMappingSource(
  MappingToolResolver tool, {
  required String target,
  required String source,
}) async {
  final outputs = tool.contract.outputs.values.where((e) => e.path == target);
  if (tool.contract.toolId != 'mapping-maintenance-promote' ||
      outputs.length != 1) {
    throw StateError('Unregistered manual Mapping target: $target');
  }
  await tool.requireNonStorePath(source);
  await tool.writeOutputs(
    (capability) => capability.copyNonStoreFile(outputs.single.id, source),
  );
}
