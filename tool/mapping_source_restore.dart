import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';
import 'package:peak_bagger/services/mapping_tool_manifest.dart';
import 'mapping_tool_support.dart';

/// Restores original named outputs; no new dataset-write authority.
Future<void> main(List<String> args) async {
  try {
    if (args.length == 4 && args.last == '--file') {
      await restoreMappingFile(
        await openMappingTool(args[0]),
        target: args[1],
        source: args[2],
      );
      return;
    }
    if (args.length != 3) {
      throw ArgumentError(
        'Usage: mapping_source_restore TOOL_ID OUTPUT_ID NON_STORE_SNAPSHOT (or TOOL_ID TARGET BACKUP --file)',
      );
    }
    final tool = await openMappingTool(args[0]);
    final output = tool.contract.outputs[args[1]];
    if (output == null ||
        !tool.contract.permittedWrites.contains(output.id) ||
        output.kind != MappingToolPathKind.directory) {
      throw StateError(
        'Recovery must use the original declared directory output',
      );
    }
    await tool.requireNonStorePath(args[2]);
    final snapshot =
        jsonDecode(await File(p.join(args[2], 'snapshot.json')).readAsString())
            as Map;
    if (snapshot['directory'] != output.path) {
      throw StateError('Recovery snapshot targets another output');
    }
    final files = (snapshot['files'] as List).cast<Map>();
    for (final file in files) {
      final child = file['path'] as String;
      if (!isSafeMappingStorePath(child)) {
        throw StateError('Unsafe recovery snapshot member');
      }
      final source = p.join(args[2], 'payload', child);
      await tool.requireNonStorePath(source);
      final integrity = await const IoMappingStoreFileSystem().inspectIntegrity(
        source,
      );
      if (integrity.sha256 != file['sha256'] ||
          integrity.size != file['size']) {
        throw StateError('Recovery backup integrity mismatch: $child');
      }
    }
    await tool.writeOutputs((outputs) async {
      for (final file in files) {
        final child = file['path'] as String;
        await outputs.copyNonStoreFile(
          output.id,
          p.join(args[2], 'payload', child),
          child: child,
        );
      }
    });
  } on Object catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}

Future<void> restoreMappingFile(
  MappingToolResolver tool, {
  required String target,
  required String source,
}) async {
  if (!isSafeMappingStorePath(target)) {
    throw StateError('Unsafe recovery target');
  }
  var outputs = tool.contract.outputs.values
      .where(
        (o) =>
            o.path == target &&
            o.kind == MappingToolPathKind.file &&
            tool.contract.permittedWrites.contains(o.id),
      )
      .toList();
  final overrides = <String, String>{};
  if (outputs.isEmpty) {
    final allowed = tool.contract.overrides.values
        .where((o) => o.output && tool.contract.permittedWrites.contains(o.id))
        .toList();
    if (allowed.length != 1) {
      throw StateError('Recovery target lacks original named output authority');
    }
    final declaration = tool.contract.outputs[allowed.single.id]!;
    if (declaration.kind != MappingToolPathKind.file) {
      throw StateError('Recovery target is not a file output');
    }
    outputs = [declaration];
    overrides[allowed.single.flag] = target;
  }
  if (outputs.length != 1) throw StateError('Recovery target is ambiguous');
  await tool.requireNonStorePath(source);
  await tool.writeOutputs(
    (capability) => capability.copyNonStoreFile(outputs.single.id, source),
    overrides: overrides,
  );
}
