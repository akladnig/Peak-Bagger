import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/router.dart';

void main() {
  test('shared shell destinations define explicit fixed contract', () {
    expect(shellDestinations.map((it) => it.branchIndex), [0, 1, 2, 3, 4]);
    expect(shellDestinations.map((it) => it.routePath), [
      '/',
      '/map',
      '/peaks',
      '/objectbox-admin',
      '/settings',
    ]);
    expect(shellDestinations.map((it) => it.label), [
      'Dashboard',
      'Map',
      'Peak Lists',
      'ObjectBox Admin',
      'Settings',
    ]);
    expect(shellDestinations.map((it) => it.title), [
      'Dashboard',
      'Map',
      'Peak Lists',
      'ObjectBox Admin',
      'Settings',
    ]);
    expect(shellDestinations.map((it) => it.keyName), [
      'nav-dashboard',
      'nav-map',
      'nav-peak-lists',
      'nav-objectbox-admin',
      'nav-settings',
    ]);
  });
}
