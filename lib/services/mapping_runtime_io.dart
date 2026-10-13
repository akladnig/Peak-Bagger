import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// macOS metadata owner. flock matches the Python controller, unlike Dart's
/// process-scoped fcntl locks. No lock inode may be unlinked/replaced by cleanup.
class MappingRuntimeIo {
  MappingRuntimeIo() {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Mapping runtime requires macOS');
    }
  }

  static final _lib = DynamicLibrary.process();
  static final _open = _lib
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32, VarArgs<(Int32,)>),
        int Function(Pointer<Utf8>, int, int)
      >('open');
  static final _flock = _lib
      .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
        'flock',
      );
  static final _close = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');
  static final _mounts = _lib
      .lookupFunction<
        Int32 Function(Pointer<Pointer<_DarwinStatFs>>, Int32),
        int Function(Pointer<Pointer<_DarwinStatFs>>, int)
      >(Abi.current() == Abi.macosX64 ? r'getmntinfo$INODE64' : 'getmntinfo');
  static final _lstat = _lib
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Pointer<_DarwinStat>),
        int Function(Pointer<Utf8>, Pointer<_DarwinStat>)
      >(Abi.current() == Abi.macosX64 ? r'lstat$INODE64' : 'lstat');
  static final _fsync = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');
  static final _fcntl = _lib
      .lookupFunction<
        Int32 Function(Int32, Int32, VarArgs<(Int32,)>),
        int Function(int, int, int)
      >('fcntl');
  static final _sysctl = _lib
      .lookupFunction<
        Int32 Function(
          Pointer<Utf8>,
          Pointer<Void>,
          Pointer<Size>,
          Pointer<Void>,
          Size,
        ),
        int Function(
          Pointer<Utf8>,
          Pointer<Void>,
          Pointer<Size>,
          Pointer<Void>,
          int,
        )
      >('sysctlbyname');
  static final _procInfo = DynamicLibrary.open('/usr/lib/libproc.dylib')
      .lookupFunction<
        Int32 Function(Int32, Int32, Uint64, Pointer<Void>, Int32),
        int Function(int, int, int, Pointer<Void>, int)
      >('proc_pidinfo');

  Map<String, Object?> owner(String token) {
    final name = 'kern.bootsessionuuid'.toNativeUtf8();
    final boot = calloc<Uint8>(128);
    final size = calloc<Size>()..value = 128;
    final process = calloc<_DarwinProcessInfo>();
    try {
      if (_sysctl(name, boot.cast(), size, nullptr, 0) != 0 ||
          _procInfo(pid, 3, 0, process.cast(), sizeOf<_DarwinProcessInfo>()) !=
              sizeOf<_DarwinProcessInfo>()) {
        throw StateError('Cannot establish native process ownership identity');
      }
      return {
        'hostId': Platform.localHostname,
        'bootId': boot.cast<Utf8>().toDartString().toLowerCase(),
        'pid': pid,
        'processStartId':
            '${process.ref.startSeconds}.${process.ref.startMicros}',
        'ownershipToken': token,
      };
    } finally {
      calloc.free(name);
      calloc.free(boot);
      calloc.free(size);
      calloc.free(process);
    }
  }

  Future<bool> exists(String path) async {
    await rejectLinks(path);
    return FileSystemEntity.type(
      path,
      followLinks: false,
    ).then((type) => type != FileSystemEntityType.notFound);
  }

  Future<List<String>> eligibleIds(String base) async {
    final directory = p.join(base, 'eligibility');
    if (!await exists(directory)) return [];
    await rejectLinks(directory);
    return Directory(directory)
        .list(followLinks: false)
        .where((e) => e.path.endsWith('.json'))
        .map((e) => p.basenameWithoutExtension(e.path))
        .toList();
  }

  Future<void> publishState(String base, String relative, Object value) async {
    if (relative != 'selection.json' &&
        relative != 'selection-transaction.json' &&
        !RegExp(
          r'^(sessions|app-failures)/[0-9a-f-]{36}\.json$',
        ).hasMatch(relative)) {
      throw ArgumentError(
        'App owner may publish only selection/session/failure metadata',
      );
    }
    final path = p.join(base, relative);
    await rejectLinks(path);
    await ensureDirectory(p.dirname(path));
    final temporary = '$path.${runtimeUuid()}.tmp';
    try {
      final file = File(temporary);
      await file.writeAsString(jsonEncode(value), flush: true);
      sync(temporary, full: true);
      await file.rename(path);
      sync(p.dirname(path));
      sync(path, full: true);
    } finally {
      final leftover = File(temporary);
      if (await leftover.exists()) await leftover.delete();
    }
  }

  Future<void> ensureDirectory(String path) async {
    await rejectLinks(path);
    if (await Directory(path).exists()) return;
    await ensureDirectory(p.dirname(path));
    await Directory(path).create();
    sync(p.dirname(path));
  }

  void sync(String path, {bool full = false}) {
    final name = path.toNativeUtf8();
    final fd = _open(name, 0 | 0x100 | 0x1000000, 0);
    calloc.free(name);
    if (fd < 0) {
      throw FileSystemException('Cannot open durability boundary', path);
    }
    try {
      if (_fsync(fd) != 0 || full && _fcntl(fd, 51, 0) != 0) {
        throw FileSystemException(
          'Cannot durably flush runtime metadata',
          path,
        );
      }
    } finally {
      _close(fd);
    }
  }

  Future<({List<int> bytes, Object? value})> readMetadata(String path) async {
    if (!await isLocal(path)) {
      throw FormatException('Runtime metadata requires local storage: $path');
    }
    await rejectLinks(path);
    final stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size > 16 * 1024 * 1024) {
      throw FormatException('Invalid/oversized local metadata: $path');
    }
    final bytes = await File(path).readAsBytes();
    if (bytes.length > 16 * 1024 * 1024) {
      throw FormatException('Oversized metadata: $path');
    }
    return (bytes: bytes, value: decodeRuntimeJson(utf8.decode(bytes)));
  }

  Future<void> rejectLinks(String path) async {
    var component = p.normalize(path);
    while (component != p.dirname(component)) {
      if (await FileSystemEntity.type(component, followLinks: false) ==
              FileSystemEntityType.link &&
          component != '/var' &&
          component != '/tmp') {
        throw FormatException(
          'Local Mapping path contains symlink: $component',
        );
      }
      component = p.dirname(component);
    }
  }

  Future<void> requireImmutable(String root) async {
    await rejectLinks(root);
    final paths = [root];
    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      if (!await isLocal(path)) {
        throw FormatException('Generation must remain on local storage: $path');
      }
      final name = path.toNativeUtf8();
      final observed = calloc<_DarwinStat>();
      try {
        if (_lstat(name, observed) != 0) {
          throw FormatException('Unreadable generation: $path');
        }
        final stat = observed.ref;
        final kind = stat.mode & 0xf000;
        if (stat.mode & 0x92 != 0 ||
            (kind != 0x8000 && kind != 0x4000) ||
            kind == 0x8000 && stat.links != 1) {
          throw FormatException(
            'Published generation is not immutable/independent: $path',
          );
        }
        if (kind == 0x4000) {
          paths.addAll(
            await Directory(
              path,
            ).list(followLinks: false).map((e) => e.path).toList(),
          );
        }
      } finally {
        calloc.free(name);
        calloc.free(observed);
      }
    }
  }

  Future<MappingLifetimeLock> lock(
    String path, {
    Duration wait = const Duration(seconds: 5),
  }) async {
    await rejectLinks(path);
    await ensureDirectory(p.dirname(path));
    final native = path.toNativeUtf8();
    // O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, Darwin constants.
    final fd = _open(native, 2 | 0x200 | 0x100 | 0x1000000, 0x180);
    calloc.free(native);
    if (fd < 0) throw FileSystemException('Cannot open lifetime lock', path);
    final elapsed = Stopwatch()..start();
    while (_flock(fd, 2 | 4) != 0) {
      if (elapsed.elapsed >= wait) {
        _close(fd);
        throw FileSystemException(
          'Mapping runtime busy; retry after current selection/cleanup',
          path,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return MappingLifetimeLock(fd, _close);
  }

  Future<bool> isLocal(String path) async {
    // MNT_NOWAIT inspects the kernel mount table, never stats/opens SMB inputs.
    // The configurable path's symlink components are rejected separately.
    final result = calloc<Pointer<_DarwinStatFs>>();
    try {
      final count = _mounts(result, 2);
      if (count <= 0) {
        throw FileSystemException('Cannot inspect local mounts', path);
      }
      final normalized = p.normalize(path);
      String? best;
      var local = false;
      for (var i = 0; i < count; i++) {
        final mount = (result.value + i).ref;
        final mountPath = utf8.decode([
          for (var n = 0; n < 1024 && mount.mountName[n] != 0; n++)
            mount.mountName[n],
        ]);
        if ((p.equals(mountPath, normalized) ||
                p.isWithin(mountPath, normalized)) &&
            (best == null || mountPath.length > best.length)) {
          best = mountPath;
          local = mount.flags & 0x1000 != 0;
        }
      }
      if (best == null) {
        throw FileSystemException('No mount for runtime path', path);
      }
      return local;
    } finally {
      calloc.free(result);
    }
  }
}

String runtimeUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Scan JSON object keys before decoding so Dart's last-key-wins decoder cannot
/// turn an ambiguous peer/config record into trusted versioned evidence.
Object? decodeRuntimeJson(String text) {
  final tokens = RegExp(
    r'"(?:[^"\\]|\\.)*"|[{}\[\]:,]',
  ).allMatches(text).map((m) => m[0]!).toList();
  final stack = <Set<String>?>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token == '{') {
      stack.add({});
    } else if (token == '[') {
      stack.add(null);
    } else if (token == '}' || token == ']') {
      if (stack.isNotEmpty) stack.removeLast();
    } else if (token.startsWith('"') &&
        i + 1 < tokens.length &&
        tokens[i + 1] == ':' &&
        stack.isNotEmpty) {
      final key = jsonDecode(token) as String;
      if (stack.last?.add(key) == false) {
        throw FormatException('Duplicate metadata key: $key');
      }
    }
  }
  return jsonDecode(text);
}

// Darwin SDK sys/stat.h __DARWIN_STRUCT_STAT64.
final class _DarwinStat extends Struct {
  @Int32()
  external int device;
  @Uint16()
  external int mode;
  @Uint16()
  external int links;
  @Uint64()
  external int inode;
  @Uint32()
  external int uid;
  @Uint32()
  external int gid;
  @Int32()
  external int rdev;
  @Array(8)
  external Array<Int64> times;
  @Int64()
  external int size;
  @Int64()
  external int blocks;
  @Int32()
  external int blockSize;
  @Uint32()
  external int flags;
  @Uint32()
  external int generation;
  @Int32()
  external int spare;
  @Array(2)
  external Array<Int64> reserved;
}

// Darwin proc_info.h proc_bsdinfo (PROC_PIDTBSDINFO).
final class _DarwinProcessInfo extends Struct {
  @Array(12)
  external Array<Uint32> ids;
  @Array(48)
  external Array<Uint8> names;
  @Array(6)
  external Array<Uint32> process;
  @Uint64()
  external int startSeconds;
  @Uint64()
  external int startMicros;
}

class MappingLifetimeLock {
  MappingLifetimeLock(this._descriptor, this._close);
  int? _descriptor;
  final int Function(int) _close;
  void close() {
    final descriptor = _descriptor;
    if (descriptor != null) {
      _descriptor = null;
      _close(descriptor);
    }
  }
}

// Darwin SDK sys/mount.h __DARWIN_STRUCT_STATFS64 (arm64 and x86_64).
final class _DarwinStatFs extends Struct {
  @Uint32()
  external int blockSize;
  @Int32()
  external int ioSize;
  @Uint64()
  external int blocks;
  @Uint64()
  external int freeBlocks;
  @Uint64()
  external int availableBlocks;
  @Uint64()
  external int files;
  @Uint64()
  external int freeFiles;
  @Array(2)
  external Array<Int32> fsId;
  @Uint32()
  external int owner;
  @Uint32()
  external int type;
  @Uint32()
  external int flags;
  @Uint32()
  external int subtype;
  @Array(16)
  external Array<Uint8> typeName;
  @Array(1024)
  external Array<Uint8> mountName;
  @Array(1024)
  external Array<Uint8> mountFrom;
  @Uint32()
  external int extendedFlags;
  @Array(7)
  external Array<Uint32> reserved;
}
