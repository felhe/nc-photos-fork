import 'dart:io';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:event_bus/event_bus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/debug_util.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/album/data_source.dart';
import 'package:nc_photos/entity/face.dart';
import 'package:nc_photos/entity/face/data_source.dart';
import 'package:nc_photos/entity/favorite.dart';
import 'package:nc_photos/entity/favorite/data_source.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file/data_source.dart';
import 'package:nc_photos/entity/local_file.dart';
import 'package:nc_photos/entity/local_file/data_source.dart';
import 'package:nc_photos/entity/person.dart';
import 'package:nc_photos/entity/person/data_source.dart';
import 'package:nc_photos/entity/search.dart';
import 'package:nc_photos/entity/search/data_source.dart';
import 'package:nc_photos/entity/share.dart';
import 'package:nc_photos/entity/share/data_source.dart';
import 'package:nc_photos/entity/sharee.dart';
import 'package:nc_photos/entity/sharee/data_source.dart';
import 'package:nc_photos/entity/sqlite_table.dart' as sql;
import 'package:nc_photos/entity/sqlite_table_isolate.dart' as sql_isolate;
import 'package:nc_photos/entity/tag.dart';
import 'package:nc_photos/entity/tag/data_source.dart';
import 'package:nc_photos/entity/tagged_file.dart';
import 'package:nc_photos/entity/tagged_file/data_source.dart';
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/mobile/android/activity.dart';
import 'package:nc_photos/mobile/android/android_info.dart';
import 'package:nc_photos/mobile/platform.dart'
    if (dart.library.html) 'package:nc_photos/web/platform.dart' as platform;
import 'package:nc_photos/mobile/self_signed_cert_manager.dart';
import 'package:nc_photos/object_extension.dart';
import 'package:nc_photos/platform/features.dart' as features;
import 'package:nc_photos/platform/k.dart' as platform_k;
import 'package:nc_photos/pref.dart';
import 'package:nc_photos/pref_util.dart' as pref_util;
import 'package:nc_photos/touch_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum InitIsolateType {
  main,

  /// Isolates with Flutter engine, e.g., those spawned by flutter_isolate or
  /// flutter_background_service
  flutterIsolate,
}

bool isNewGMapsRenderer() => _isNewGMapsRenderer;

Future<void> init(InitIsolateType isolateType) async {
  if (_hasInitedInThisIsolate) {
    _log.warning("[init] Already initialized in this isolate");
    return;
  }

  initLog();
  await _initDeviceInfo();
  initDrift();
  if (isolateType == InitIsolateType.main) {
    await _initDriftWorkaround();
  }
  _initKiwi();
  await _initPref();
  await _initAccountPrefs();
  _initEquatable();
  if (features.isSupportSelfSignedCert) {
    _initSelfSignedCertManager();
  }
  await _initDiContainer(isolateType);
  _initVisibilityDetector();

  if (platform_k.isAndroid) {
    if (isolateType == InitIsolateType.main) {
      try {
        _isNewGMapsRenderer = await Activity.isNewGMapsRenderer();
      } catch (e, stackTrace) {
        _log.severe("[init] Failed while isNewGMapsRenderer", e, stackTrace);
      }
    }
  }

  await _initFirebase();
  await _initAds();

  _hasInitedInThisIsolate = true;
}

void initLog() {
  if (_hasInitedInThisIsolate) {
    return;
  }

  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    // dev.log(
    //   "${record.level.name} ${record.time}: ${record.message}",
    //   time: record.time,
    //   sequenceNumber: record.sequenceNumber,
    //   level: record.level.value,
    //   name: record.loggerName,
    // );
    String msg =
        "[${record.loggerName}] ${record.level.name} ${record.time}: ${record.message}";
    if (record.error != null) {
      msg += " (throw: ${record.error.runtimeType} { ${record.error} })";
    }
    if (record.stackTrace != null) {
      msg += "\nStack Trace:\n${record.stackTrace}";
    }

    if (kDebugMode) {
      // show me colors!
      int color;
      if (record.level >= Level.SEVERE) {
        color = 91;
      } else if (record.level >= Level.WARNING) {
        color = 33;
      } else if (record.level >= Level.INFO) {
        color = 34;
      } else if (record.level >= Level.FINER) {
        color = 32;
      } else {
        color = 90;
      }
      msg = "\x1B[${color}m$msg\x1B[0m";
    }
    debugPrint(msg, wrapWidth: 1024);
    LogCapturer().onLog(msg);

    if (_shouldReportCrashlytics(record)) {
      FirebaseCrashlytics.instance.recordError(
        record.error,
        record.stackTrace,
        reason: record.message,
        printDetails: false,
      );
    }
  });
}

void initDrift() {
  driftRuntimeOptions.debugPrint = (log) => debugPrint(log, wrapWidth: 1024);
}

Future<void> _initDriftWorkaround() async {
  if (platform_k.isAndroid && AndroidInfo().sdkInt < 24) {
    _log.info("[_initDriftWorkaround] Workaround Android 6- bug");
    // see: https://github.com/flutter/flutter/issues/73318 and
    // https://github.com/simolus3/drift/issues/895
    await platform.applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
}

Future<void> _initPref() async {
  final provider = PrefSharedPreferencesProvider();
  await provider.init();
  final pref = Pref.scoped(provider);
  Pref.setGlobalInstance(pref);

  if (Pref().getLastVersion() == null) {
    if (Pref().getSetupProgress() == null) {
      // new install
      await Pref().setLastVersion(k.version);
    } else {
      // v6 is the last version without saving the version number in pref
      await Pref().setLastVersion(6);
    }
  }
}

Future<void> _initAccountPrefs() async {
  for (final a in Pref().getAccounts3Or([])) {
    try {
      AccountPref.setGlobalInstance(a, await pref_util.loadAccountPref(a));
    } catch (e, stackTrace) {
      _log.shout("[_initAccountPrefs] Failed reading pref for account: $a", e,
          stackTrace);
    }
  }
}

Future<void> _initDeviceInfo() async {
  if (platform_k.isAndroid) {
    await AndroidInfo.init();
  }
}

void _initKiwi() {
  final kiwi = KiwiContainer();
  kiwi.registerInstance<EventBus>(EventBus());
}

void _initEquatable() {
  EquatableConfig.stringify = false;
}

void _initSelfSignedCertManager() {
  SelfSignedCertManager().init();
}

Future<void> _initDiContainer(InitIsolateType isolateType) async {
  final c = DiContainer.late();
  c.pref = Pref();
  c.sqliteDb = await _createDb(isolateType);

  c.albumRepo = AlbumRepo(AlbumCachedDataSource(c));
  c.albumRepoLocal = AlbumRepo(AlbumSqliteDbDataSource(c));
  c.faceRepo = const FaceRepo(FaceRemoteDataSource());
  c.fileRepo = FileRepo(FileCachedDataSource(c));
  c.fileRepoRemote = const FileRepo(FileWebdavDataSource());
  c.fileRepoLocal = FileRepo(FileSqliteDbDataSource(c));
  c.personRepo = const PersonRepo(PersonRemoteDataSource());
  c.personRepoRemote = const PersonRepo(PersonRemoteDataSource());
  c.personRepoLocal = PersonRepo(PersonSqliteDbDataSource(c.sqliteDb));
  c.shareRepo = ShareRepo(ShareRemoteDataSource());
  c.shareeRepo = ShareeRepo(ShareeRemoteDataSource());
  c.favoriteRepo = const FavoriteRepo(FavoriteRemoteDataSource());
  c.tagRepo = const TagRepo(TagRemoteDataSource());
  c.tagRepoRemote = const TagRepo(TagRemoteDataSource());
  c.tagRepoLocal = TagRepo(TagSqliteDbDataSource(c.sqliteDb));
  c.taggedFileRepo = const TaggedFileRepo(TaggedFileRemoteDataSource());
  c.searchRepo = SearchRepo(SearchSqliteDbDataSource(c));
  c.touchManager = TouchManager(c);

  if (platform_k.isAndroid) {
    // local file currently only supported on Android
    c.localFileRepo = const LocalFileRepo(LocalFileMediaStoreDataSource());
  }

  KiwiContainer().registerInstance<DiContainer>(c);
}

void _initVisibilityDetector() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
}

Future<sql.SqliteDb> _createDb(InitIsolateType isolateType) async {
  switch (isolateType) {
    case InitIsolateType.main:
      // use driftIsolate to prevent DB blocking the UI thread
      if (platform_k.isWeb) {
        // no isolate support on web
        return sql.SqliteDb();
      } else {
        return sql_isolate.createDb();
      }

    case InitIsolateType.flutterIsolate:
      // service already runs in an isolate
      return sql.SqliteDb();
  }
}

Future<InitializationStatus> _initAds() {
  return MobileAds.instance.initialize();
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp();

  // Crashlytics
  if (features.isSupportCrashlytics) {
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      await FirebaseCrashlytics.instance.deleteUnsentReports();
    }
  }
}

bool _shouldReportCrashlytics(LogRecord record) {
  if (kDebugMode ||
      !features.isSupportCrashlytics ||
      record.level < Level.SHOUT) {
    return false;
  }
  final e = record.error;
  // We ignore these SocketExceptions as they are likely caused by an unstable
  // internet connection
  // 7: No address associated with hostname
  // 101: Network is unreachable
  // 103: Software caused connection abort
  // 104: Connection reset by peer
  // 110: Connection timed out
  // 113: No route to host
  if (e is SocketException &&
      e.osError?.errorCode.isIn([7, 101, 103, 104, 110, 113]) == true) {
    return false;
  }
  return true;
}

final _log = Logger("app_init");
var _hasInitedInThisIsolate = false;
var _isNewGMapsRenderer = false;
