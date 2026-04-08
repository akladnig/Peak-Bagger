import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';

late final Store objectboxStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  objectboxStore = openStore();

  runApp(ProviderScope(child: App()));
}
