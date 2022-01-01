import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:idb_shim/idb.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/ci_string.dart';
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/album/upgrader.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/mobile/platform.dart'
    if (dart.library.html) 'package:nc_photos/web/platform.dart' as platform;
import 'package:nc_photos/object_extension.dart';
import 'package:nc_photos/type.dart';
import 'package:synchronized/synchronized.dart';

class AppDb {
  static const dbName = "app.db";
  static const dbVersion = 4;
  static const albumStoreName = "albums";
  static const file2StoreName = "files2";
  static const dirStoreName = "dirs";

  factory AppDb() => _inst;

  AppDb._();

  /// Run [fn] with an opened database instance
  ///
  /// This function guarantees that:
  /// 1) Database is always closed after [fn] exits, even with an error
  /// 2) Only at most 1 database instance being opened at any time
  Future<T> use<T>(FutureOr<T> Function(Database) fn) async {
    // make sure only one client is opening the db
    return await _lock.synchronized(() async {
      final db = await _open();
      try {
        return await fn(db);
      } finally {
        db.close();
      }
    });
  }

  /// Open the database
  Future<Database> _open() async {
    final dbFactory = platform.getDbFactory();
    return dbFactory.open(dbName, version: dbVersion,
        onUpgradeNeeded: (event) async {
      _log.info("[_open] Upgrade database: ${event.oldVersion} -> $dbVersion");

      final db = event.database;
      // ignore: unused_local_variable
      ObjectStore? albumStore, file2Store, dirStore;
      if (event.oldVersion < 2) {
        // version 2 store things in a new way, just drop all
        try {
          db.deleteObjectStore(albumStoreName);
        } catch (_) {}
        albumStore = db.createObjectStore(albumStoreName);
        albumStore.createIndex(
            AppDbAlbumEntry.indexName, AppDbAlbumEntry.keyPath);
      }
      if (event.oldVersion < 3) {
        // new object store in v3
        // no longer relevant in v4

        // recreate file store from scratch
        // no longer relevant in v4
      }
      if (event.oldVersion < 4) {
        try {
          db.deleteObjectStore(_fileDbStoreName);
        } catch (_) {}
        try {
          db.deleteObjectStore(_fileStoreName);
        } catch (_) {}

        file2Store = db.createObjectStore(file2StoreName);
        file2Store.createIndex(AppDbFile2Entry.strippedPathIndexName,
            AppDbFile2Entry.strippedPathKeyPath);

        dirStore = db.createObjectStore(dirStoreName);
      }
    });
  }

  static late final _inst = AppDb._();
  final _lock = Lock(reentrant: true);

  static const _fileDbStoreName = "filesDb";
  static const _fileStoreName = "files";

  static final _log = Logger("app_db.AppDb");
}

class AppDbAlbumEntry {
  static const indexName = "albumStore_path_index";
  static const keyPath = ["path", "index"];
  static const maxDataSize = 160;

  AppDbAlbumEntry(this.path, this.index, this.album);

  JsonObj toJson() {
    return {
      "path": path,
      "index": index,
      "album": album.toAppDbJson(),
    };
  }

  factory AppDbAlbumEntry.fromJson(JsonObj json, Account account) {
    return AppDbAlbumEntry(
      json["path"],
      json["index"],
      Album.fromJson(
        json["album"].cast<String, dynamic>(),
        upgraderFactory: DefaultAlbumUpgraderFactory(
          account: account,
          logFilePath: json["path"],
        ),
      )!,
    );
  }

  static String toPath(Account account, String filePath) =>
      "${account.url}/$filePath";
  static String toPathFromFile(Account account, File albumFile) =>
      toPath(account, albumFile.path);
  static String toPrimaryKey(Account account, File albumFile, int index) =>
      "${toPathFromFile(account, albumFile)}[$index]";

  final String path;
  final int index;
  // properties other than Album.items is undefined when index > 0
  final Album album;
}

class AppDbFile2Entry with EquatableMixin {
  static const strippedPathIndexName = "server_userId_strippedPath";
  static const strippedPathKeyPath = ["server", "userId", "strippedPath"];

  AppDbFile2Entry._(this.server, this.userId, this.strippedPath, this.file);

  factory AppDbFile2Entry.fromFile(Account account, File file) =>
      AppDbFile2Entry._(
          account.url, account.username, file.strippedPathWithEmpty, file);

  factory AppDbFile2Entry.fromJson(JsonObj json) => AppDbFile2Entry._(
        json["server"],
        (json["userId"] as String).toCi(),
        json["strippedPath"],
        File.fromJson(json["file"].cast<String, dynamic>()),
      );

  JsonObj toJson() => {
        "server": server,
        "userId": userId.toCaseInsensitiveString(),
        "strippedPath": strippedPath,
        "file": file.toJson(),
      };

  static String toPrimaryKey(Account account, int fileId) =>
      "${account.url}/${account.username.toCaseInsensitiveString()}/$fileId";

  static String toPrimaryKeyForFile(Account account, File file) =>
      toPrimaryKey(account, file.fileId!);

  static List<Object> toStrippedPathIndexKey(
          Account account, String strippedPath) =>
      [
        account.url,
        account.username.toCaseInsensitiveString(),
        strippedPath == "." ? "" : strippedPath
      ];

  static List<Object> toStrippedPathIndexKeyForFile(
          Account account, File file) =>
      toStrippedPathIndexKey(account, file.strippedPathWithEmpty);

  /// Return the lower bound key used to query files under [dir] and its sub
  /// dirs
  static List<Object> toStrippedPathIndexLowerKeyForDir(
          Account account, File dir) =>
      [
        account.url,
        account.username.toCaseInsensitiveString(),
        dir.strippedPath.run((p) => p == "." ? "" : "$p/")
      ];

  /// Return the upper bound key used to query files under [dir] and its sub
  /// dirs
  static List<Object> toStrippedPathIndexUpperKeyForDir(
      Account account, File dir) {
    return toStrippedPathIndexLowerKeyForDir(account, dir).run((k) {
      k[2] = (k[2] as String) + "\uffff";
      return k;
    });
  }

  @override
  get props => [
        server,
        userId,
        strippedPath,
        file,
      ];

  /// Server URL where this file belongs to
  final String server;
  final CiString userId;
  final String strippedPath;
  final File file;
}

class AppDbDirEntry with EquatableMixin {
  AppDbDirEntry._(
      this.server, this.userId, this.strippedPath, this.dir, this.children);

  factory AppDbDirEntry.fromFiles(
          Account account, File dir, List<File> children) =>
      AppDbDirEntry._(
        account.url,
        account.username,
        dir.strippedPathWithEmpty,
        dir,
        children.map((f) => f.fileId!).toList(),
      );

  factory AppDbDirEntry.fromJson(JsonObj json) => AppDbDirEntry._(
        json["server"],
        (json["userId"] as String).toCi(),
        json["strippedPath"],
        File.fromJson((json["dir"] as Map).cast<String, dynamic>()),
        json["children"].cast<int>(),
      );

  JsonObj toJson() => {
        "server": server,
        "userId": userId.toCaseInsensitiveString(),
        "strippedPath": strippedPath,
        "dir": dir.toJson(),
        "children": children,
      };

  static String toPrimaryKeyForDir(Account account, File dir) =>
      "${account.url}/${account.username.toCaseInsensitiveString()}/${dir.strippedPathWithEmpty}";

  /// Return the lower bound key used to query dirs under [root] and its sub
  /// dirs
  static String toPrimaryLowerKeyForSubDirs(Account account, File root) {
    final strippedPath = root.strippedPath.run((p) => p == "." ? "" : "$p/");
    return "${account.url}/${account.username.toCaseInsensitiveString()}/$strippedPath";
  }

  /// Return the upper bound key used to query dirs under [root] and its sub
  /// dirs
  static String toPrimaryUpperKeyForSubDirs(Account account, File root) =>
      toPrimaryLowerKeyForSubDirs(account, root) + "\uffff";

  @override
  get props => [
        server,
        userId,
        strippedPath,
        dir,
        children,
      ];

  /// Server URL where this file belongs to
  final String server;
  final CiString userId;
  final String strippedPath;
  final File dir;
  final List<int> children;
}
