import 'package:peak_bagger/models/track_replacement_recovery_issue.dart';
import 'package:peak_bagger/objectbox.g.dart';

abstract interface class TrackReplacementRecoveryIssueStore {
  TrackReplacementRecoveryIssue? getPending();
  void save(TrackReplacementRecoveryIssue issue);
  void clear();
}

class ObjectBoxTrackReplacementRecoveryIssueStore
    implements TrackReplacementRecoveryIssueStore {
  ObjectBoxTrackReplacementRecoveryIssueStore(this._store);

  final Store _store;

  Box<TrackReplacementRecoveryIssue> get _box =>
      _store.box<TrackReplacementRecoveryIssue>();

  @override
  TrackReplacementRecoveryIssue? getPending() => _box.getAll().firstOrNull;

  @override
  void save(TrackReplacementRecoveryIssue issue) {
    _box.removeAll();
    _box.put(issue);
  }

  @override
  void clear() => _box.removeAll();
}

class InMemoryTrackReplacementRecoveryIssueStore
    implements TrackReplacementRecoveryIssueStore {
  TrackReplacementRecoveryIssue? _issue;

  @override
  TrackReplacementRecoveryIssue? getPending() => _issue;

  @override
  void save(TrackReplacementRecoveryIssue issue) {
    _issue = issue;
  }

  @override
  void clear() {
    _issue = null;
  }
}
