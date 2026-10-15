import 'dart:io';
import 'package:peak_bagger/services/mapping_runtime_io.dart';

Future<void> main(List<String> arguments) async {
  final held = await MappingRuntimeIo().lock(arguments.single);
  stdout.writeln('owned');
  await Future<void>.delayed(const Duration(days: 1));
  held.close();
}
