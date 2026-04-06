import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/widgets/theme_toggle.dart';

class PeakListsScreen extends ConsumerWidget {
  const PeakListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peak Lists'),
        actions: const [ThemeToggle()],
      ),
      body: const Center(child: Text('Peak Lists')),
    );
  }
}
