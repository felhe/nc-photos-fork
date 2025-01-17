import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/event/event.dart';
import 'package:nc_photos/pref.dart';
import 'package:nc_photos/reverse_geocoder.dart';
import 'package:nc_photos/use_case/update_missing_metadata.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:to_string/to_string.dart';

part 'metadata_task_manager.g.dart';

/// Task to update metadata for missing files
@npLog
@ToString(ignorePrivate: true)
class MetadataTask {
  MetadataTask(this._c, this.account, this.pref) : assert(require(_c));

  static bool require(DiContainer c) => DiContainer.has(c, DiType.fileRepo);

  @override
  String toString() => _$toString();

  Future<void> call() async {
    try {
      final shareFolder =
          File(path: file_util.unstripPath(account, pref.getShareFolderOr()));
      bool hasScanShareFolder = false;
      final geocoder = ReverseGeocoder();
      await geocoder.init();
      for (final r in account.roots) {
        final dir = File(path: file_util.unstripPath(account, r));
        hasScanShareFolder |= file_util.isOrUnderDir(shareFolder, dir);
        final op = UpdateMissingMetadata(_c.fileRepo,
            const _UpdateMissingMetadataConfigProvider(), geocoder);
        await for (final _ in op(account, dir)) {
          if (!Pref().isEnableExifOr()) {
            _log.info("[call] EXIF disabled, task ending immaturely");
            op.stop();
            return;
          }
        }
      }
      if (!hasScanShareFolder) {
        final op = UpdateMissingMetadata(_c.fileRepo,
            const _UpdateMissingMetadataConfigProvider(), geocoder);
        await for (final _ in op(
          account,
          shareFolder,
          isRecursive: false,
          filter: (f) => f.ownerId != account.userId,
        )) {
          if (!Pref().isEnableExifOr()) {
            _log.info("[call] EXIF disabled, task ending immaturely");
            op.stop();
            return;
          }
        }
      }
    } finally {
      KiwiContainer()
          .resolve<EventBus>()
          .fire(const MetadataTaskStateChangedEvent(MetadataTaskState.idle));
    }
  }

  final DiContainer _c;

  final Account account;
  @ignore
  final AccountPref pref;
}

/// Manage metadata tasks to run concurrently
@npLog
class MetadataTaskManager {
  factory MetadataTaskManager() {
    _inst ??= MetadataTaskManager._();
    return _inst!;
  }

  MetadataTaskManager._() {
    _stateChangedListener.begin();
    _handleStream();
  }

  /// Add a task to the queue
  void addTask(MetadataTask task) {
    _log.info("[addTask] New task added: $task");
    _streamController.add(task);
  }

  MetadataTaskState get state => _currentState;

  void _onMetadataTaskStateChanged(MetadataTaskStateChangedEvent ev) {
    if (ev.state != _currentState) {
      _currentState = ev.state;
    }
  }

  Future<void> _handleStream() async {
    await for (final task in _streamController.stream) {
      if (Pref().isEnableExifOr()) {
        _log.info("[_doTask] Executing task: $task");
        await task();
      } else {
        _log.info("[_doTask] Ignoring task: $task");
      }
    }
  }

  final _streamController = StreamController<MetadataTask>.broadcast();

  var _currentState = MetadataTaskState.idle;
  late final _stateChangedListener =
      AppEventListener<MetadataTaskStateChangedEvent>(
          _onMetadataTaskStateChanged);

  static MetadataTaskManager? _inst;
}

class _UpdateMissingMetadataConfigProvider
    implements UpdateMissingMetadataConfigProvider {
  const _UpdateMissingMetadataConfigProvider();

  @override
  isWifiOnly() async => Pref().shouldProcessExifWifiOnlyOr();
}
