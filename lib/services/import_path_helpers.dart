import 'dart:io';

/// Shared path helpers for Bushwalking root resolution.
///
/// This is the canonical root used by importer storage semantics.
/// The file picker may use separate fallback behavior for dialog usability.
String resolveBushwalkingRoot() {
  final home = _resolveHomeDirectory();
  if (home == null) {
    return Directory.current.path;
  }

  final documentsBushwalking = '$home/Documents/Bushwalking';
  if (Directory(documentsBushwalking).existsSync()) {
    return documentsBushwalking;
  }

  return home;
}

String? _resolveHomeDirectory() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return home;
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.isNotEmpty) {
    return userProfile;
  }

  return null;
}
