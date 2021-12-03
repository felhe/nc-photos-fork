import 'package:bloc_test/bloc_test.dart';
import 'package:nc_photos/bloc/list_album_share_outlier.dart';
import 'package:nc_photos/ci_string.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/object_extension.dart';
import 'package:test/test.dart';

import '../mock_type.dart';
import '../test_util.dart' as util;

void main() {
  group("ListAlbumShareOutlierBloc", () {
    test("intial state", _initialState);
    group("ListAlbumShareOutlierBlocQuery", () {
      group("unshared album", () {
        _testQueryUnsharedAlbumExtraShare("extra share");
        _testQueryUnsharedAlbumExtraJsonShare("extra json share");
      });
      group("shared album", () {
        group("owned", () {
          _testQuerySharedAlbumMissingShare("missing share");
          _testQuerySharedAlbumMissingManagedOtherShare(
              "missing managed other share");
          _testQuerySharedAlbumMissingUnmanagedOtherShare(
              "missing unmanaged other share");
          _testQuerySharedAlbumMissingJsonShare("missing json share");

          _testQuerySharedAlbumExtraShare("extra share");
          _testQuerySharedAlbumExtraManagedOtherShare(
              "extra managed other share");
          _testQuerySharedAlbumExtraUnmanagedOtherShare(
              "extra unmanaged other share");
          _testQuerySharedAlbumExtraJsonShare("extra json share");
        });
        group("not owned", () {
          _testQuerySharedAlbumNotOwnedMissingShareToOwner("missing share");
          _testQuerySharedAlbumNotOwnedMissingManagedShare(
              "missing managed share");
          _testQuerySharedAlbumNotOwnedMissingUnmanagedShare(
              "missing unmanaged share");
          _testQuerySharedAlbumNotOwnedMissingJsonShare("missing json share");

          _testQuerySharedAlbumNotOwnedExtraManagedShare("extra managed share");
          _testQuerySharedAlbumNotOwnedExtraUnmanagedShare(
              "extra unmanaged share");
          _testQuerySharedAlbumNotOwnedExtraJsonShare("extra json share");
        });
      });
    });
  });
}

void _initialState() {
  final c = DiContainer(
    shareRepo: MockShareRepo(),
    shareeRepo: MockShareeRepo(),
    appDb: MockAppDb(),
  );
  final bloc = ListAlbumShareOutlierBloc(c);
  expect(bloc.state.account, null);
  expect(bloc.state.items, const []);
}

/// Query an album that is not shared, but with shared file (admin -> user1)
///
/// Expect: emit the file with extra share (admin -> user1)
void _testQueryUnsharedAlbumExtraShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder()..addFileItem(files[0])).build();
  final file1 = files[0];
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: file1, shareWith: "user1"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(file1, [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "0", file: file1, shareWith: "user1")),
        ]),
      ]),
    ],
  );
}

/// Query an album that is not shared, but the album json is shared
/// (admin -> user1)
///
/// Expect: emit the json file with extra share (admin -> user1)
void _testQueryUnsharedAlbumExtraJsonShare(String description) {
  final account = util.buildAccount();
  final album = util.AlbumBuilder().build();
  final albumFile = album.albumFile!;
  final c = DiContainer(
    shareRepo: MockShareMemoryRepo([
      util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
    ]),
    shareeRepo: MockShareeMemoryRepo([
      util.buildSharee(shareWith: "user1".toCi()),
    ]),
    appDb: MockAppDb(),
  );

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(albumFile, [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "0", file: albumFile, shareWith: "user1")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1), with file not shared (admin -> user1)
///
/// Expect: emit the file with missing share (admin -> user1)
void _testQuerySharedAlbumMissingShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder()
        ..addFileItem(files[0])
        ..addShare("user1"))
      .build();
  final file1 = files[0];
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(file1, [
          ListAlbumShareOutlierMissingShareItem("user1".toCi(), "user1"),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1, user2), with file added by user1,
/// managed by admin, not shared (admin -> user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumMissingManagedOtherShare(String description) {
  final account = util.buildAccount();
  final files = (util.FilesBuilder(initialFileId: 1)
        ..addJpeg("user1/test1.jpg", ownerId: "user1"))
      .build();
  final album = (util.AlbumBuilder()
        // added before album shared, thus managed by album owner
        ..addFileItem(files[0], addedBy: "user1")
        ..addShare("user1", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("user2", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5)))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(id: "1", file: albumFile, shareWith: "user2"),
          util.buildShare(
              id: "2", file: files[0], uidOwner: "user1", shareWith: "admin"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierMissingShareItem("user2".toCi(), "user2"),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1, user2), with file added by user1,
/// managed by user1, not shared (user1 -> user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumMissingUnmanagedOtherShare(String description) {
  final account = util.buildAccount();
  final files = (util.FilesBuilder(initialFileId: 1)
        ..addJpeg("user1/test1.jpg", ownerId: "user1"))
      .build();
  final album = (util.AlbumBuilder()
        // added after album shared, thus managed by adder
        ..addFileItem(files[0],
            addedBy: "user1", addedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("user1")
        ..addShare("user2"))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(id: "1", file: albumFile, shareWith: "user2"),
          util.buildShare(
              id: "2", file: files[0], uidOwner: "user1", shareWith: "admin"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, []),
    ],
  );
}

/// Query a shared album (admin -> user1), with album json not shared
///
/// Expect: emit the file with missing share (admin -> user1)
void _testQuerySharedAlbumMissingJsonShare(String description) {
  final account = util.buildAccount();
  final album = (util.AlbumBuilder()..addShare("user1")).build();
  final albumFile = album.albumFile!;
  final c = DiContainer(
    shareRepo: MockShareMemoryRepo(),
    shareeRepo: MockShareeMemoryRepo([
      util.buildSharee(shareWith: "user1".toCi()),
    ]),
    appDb: MockAppDb(),
  );

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(albumFile, [
          ListAlbumShareOutlierMissingShareItem("user1".toCi(), "user1"),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1), with file shared
/// (admin -> user1, user2)
///
/// Expect: emit the file with extra share (admin -> user2)
void _testQuerySharedAlbumExtraShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder()
        ..addFileItem(files[0])
        ..addShare("user1"))
      .build();
  final file1 = files[0];
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(id: "1", file: files[0], shareWith: "user1"),
          util.buildShare(id: "2", file: files[0], shareWith: "user2"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(file1, [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "2", file: files[0], shareWith: "user2")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1), with file added by user1,
/// managed by admin, shared (admin -> user1, user2)
///
/// Expect: emit the file with extra share (admin -> user2)
void _testQuerySharedAlbumExtraManagedOtherShare(String description) {
  final account = util.buildAccount();
  final files = (util.FilesBuilder(initialFileId: 1)
        ..addJpeg("user1/test1.jpg", ownerId: "user1"))
      .build();
  final album = (util.AlbumBuilder()
        // added before album shared, thus managed by album owner
        ..addFileItem(files[0], addedBy: "user1")
        ..addShare("user1", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5)))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(
              id: "1", file: files[0], uidOwner: "user1", shareWith: "admin"),
          util.buildShare(id: "2", file: files[0], shareWith: "user2"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "2", file: files[0], shareWith: "user2")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (admin -> user1), with file added by user1, managed by
/// user1, shared (user1 -> admin, user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumExtraUnmanagedOtherShare(String description) {
  final account = util.buildAccount();
  final files = (util.FilesBuilder(initialFileId: 1)
        ..addJpeg("user1/test1.jpg", ownerId: "user1"))
      .build();
  final album = (util.AlbumBuilder()
        // added after album shared, thus managed by adder
        ..addFileItem(files[0],
            addedBy: "user1", addedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("user1"))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(
              id: "1", file: files[0], uidOwner: "user1", shareWith: "admin"),
          util.buildShare(
              id: "2", file: files[0], uidOwner: "user1", shareWith: "user2"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, []),
    ],
  );
}

/// Query a shared album (admin -> user1), with album json shared
/// (admin -> user1, user2)
///
/// Expect: emit the file with extra share (admin -> user2)
void _testQuerySharedAlbumExtraJsonShare(String description) {
  final account = util.buildAccount();
  final album = (util.AlbumBuilder()..addShare("user1")).build();
  final albumFile = album.albumFile!;
  final c = DiContainer(
    shareRepo: MockShareMemoryRepo([
      util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
      util.buildShare(id: "1", file: albumFile, shareWith: "user2"),
    ]),
    shareeRepo: MockShareeMemoryRepo([
      util.buildSharee(shareWith: "user1".toCi()),
      util.buildSharee(shareWith: "user2".toCi()),
    ]),
    appDb: MockAppDb(),
  );

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(albumFile, [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "1", file: albumFile, shareWith: "user2")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (user1 -> admin), with file added by admin not shared
/// (admin -> user1)
///
/// Expect: emit the file with missing share (admin -> user1)
void _testQuerySharedAlbumNotOwnedMissingShareToOwner(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder(ownerId: "user1")
        ..addFileItem(files[0])
        ..addShare("admin"))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(
              id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierMissingShareItem("user1".toCi(), "user1"),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (user1 -> admin, user2), with file added by admin,
/// managed by admin, not shared (admin -> user2)
///
/// Expect: emit the file with missing share (admin -> user2)
void _testQuerySharedAlbumNotOwnedMissingManagedShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder(ownerId: "user1")
        // added after album shared, thus managed by adder
        ..addFileItem(files[0], addedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("admin")
        ..addShare("user2"))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(
              id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
          util.buildShare(
              id: "1", file: albumFile, uidOwner: "user1", shareWith: "user2"),
          util.buildShare(id: "2", file: files[0], shareWith: "user1"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierMissingShareItem("user2".toCi(), "user2"),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (user1 -> admin, user2), with file added by admin,
/// managed by user1, not shared (user1 -> user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumNotOwnedMissingUnmanagedShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder(ownerId: "user1")
        // added before album shared, thus managed by album owner
        ..addFileItem(files[0], addedBy: "admin")
        ..addShare("admin", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("user2", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5)))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(id: "0", file: albumFile, shareWith: "user1"),
          util.buildShare(id: "1", file: albumFile, shareWith: "user2"),
          util.buildShare(id: "2", file: files[0], shareWith: "user1"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, []),
    ],
  );
}

/// Query a shared album (user1 -> admin, user2), with missing album json share
/// (user1 -> user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumNotOwnedMissingJsonShare(String description) {
  final account = util.buildAccount();
  final album = (util.AlbumBuilder(ownerId: "user1")
        ..addShare("admin")
        ..addShare("user2"))
      .build();
  final albumFile = album.albumFile!;
  final c = DiContainer(
    shareRepo: MockShareMemoryRepo([
      util.buildShare(
          id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
    ]),
    shareeRepo: MockShareeMemoryRepo([
      util.buildSharee(shareWith: "user1".toCi()),
      util.buildSharee(shareWith: "user2".toCi()),
    ]),
    appDb: MockAppDb(),
  );

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, []),
    ],
  );
}

/// Query a shared album (user1 -> admin), with file added by admin, managed by
/// admin, shared (admin -> user1, user2)
///
/// Expect: emit the file with missing share (admin -> user2)
void _testQuerySharedAlbumNotOwnedExtraManagedShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder(ownerId: "user1")
        // added after album shared, thus managed by adder
        ..addFileItem(files[0], addedAt: DateTime.utc(2021, 1, 2, 3, 4, 5))
        ..addShare("admin"))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(
              id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
          util.buildShare(id: "1", file: files[0], shareWith: "user1"),
          util.buildShare(id: "2", file: files[0], shareWith: "user2"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "2", file: files[0], shareWith: "user2")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (user1 -> admin), with file added by admin, managed by
/// user1, shared (admin -> user1, user2)
///
/// Expect: emit the file with missing share (admin -> user2)
void _testQuerySharedAlbumNotOwnedExtraUnmanagedShare(String description) {
  final account = util.buildAccount();
  final files =
      (util.FilesBuilder(initialFileId: 1)..addJpeg("admin/test1.jpg")).build();
  final album = (util.AlbumBuilder(ownerId: "user1")
        // added before album shared, thus managed by album owner
        ..addFileItem(files[0], addedBy: "admin")
        ..addShare("admin", sharedAt: DateTime.utc(2021, 1, 2, 3, 4, 5)))
      .build();
  final albumFile = album.albumFile!;
  late final DiContainer c;

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    setUp: () async {
      c = DiContainer(
        shareRepo: MockShareMemoryRepo([
          util.buildShare(
              id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
          util.buildShare(id: "1", file: files[0], shareWith: "user1"),
          util.buildShare(id: "2", file: files[0], shareWith: "user2"),
        ]),
        shareeRepo: MockShareeMemoryRepo([
          util.buildSharee(shareWith: "user1".toCi()),
          util.buildSharee(shareWith: "user2".toCi()),
        ]),
        appDb: await MockAppDb().applyFuture((obj) async {
          await util.fillAppDb(obj, account, files);
        }),
      );
    },
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, [
        ListAlbumShareOutlierItem(files[0], [
          ListAlbumShareOutlierExtraShareItem(
              util.buildShare(id: "2", file: files[0], shareWith: "user2")),
        ]),
      ]),
    ],
  );
}

/// Query a shared album (user1 -> admin), with album json share
/// (user1 -> admin, user2)
///
/// Expect: emit empty list
void _testQuerySharedAlbumNotOwnedExtraJsonShare(String description) {
  final account = util.buildAccount();
  final album =
      (util.AlbumBuilder(ownerId: "user1")..addShare("admin")).build();
  final albumFile = album.albumFile!;
  final c = DiContainer(
    shareRepo: MockShareMemoryRepo([
      util.buildShare(
          id: "0", file: albumFile, uidOwner: "user1", shareWith: "admin"),
      util.buildShare(
          id: "1", file: albumFile, uidOwner: "user1", shareWith: "user2"),
    ]),
    shareeRepo: MockShareeMemoryRepo([
      util.buildSharee(shareWith: "user1".toCi()),
      util.buildSharee(shareWith: "user2".toCi()),
    ]),
    appDb: MockAppDb(),
  );

  blocTest<ListAlbumShareOutlierBloc, ListAlbumShareOutlierBlocState>(
    description,
    build: () => ListAlbumShareOutlierBloc(c),
    act: (bloc) => bloc.add(ListAlbumShareOutlierBlocQuery(account, album)),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      ListAlbumShareOutlierBlocLoading(account, []),
      ListAlbumShareOutlierBlocSuccess(account, []),
    ],
  );
}
