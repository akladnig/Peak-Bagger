/// One process-lifetime generation pin. Session shutdown cannot release the OS
/// lock while any pending open, dataset, or worker still owns native resources.
class MappingSessionProtection {
  MappingSessionProtection(this._release);
  final void Function() _release;
  var _nativeOwners = 0;
  var _closing = false;
  var _released = false;

  void Function() retainNative() {
    if (_closing) throw StateError('Mapping session is closing');
    _nativeOwners++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _nativeOwners--;
      _tryRelease();
    };
  }

  void close() {
    _closing = true;
    _tryRelease();
  }

  void _tryRelease() {
    if (_closing && _nativeOwners == 0 && !_released) {
      _released = true;
      _release();
    }
  }
}
