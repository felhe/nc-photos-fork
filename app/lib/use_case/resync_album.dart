import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/debug_util.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/album/item.dart';
import 'package:nc_photos/entity/album/provider.dart';
import 'package:nc_photos/use_case/find_file.dart';
import 'package:np_codegen/np_codegen.dart';

part 'resync_album.g.dart';

/// Resync files inside an album with the file db
@npLog
class ResyncAlbum {
  ResyncAlbum(this._c)
      : assert(require(_c)),
        assert(FindFile.require(_c));

  static bool require(DiContainer c) => true;

  Future<List<AlbumItem>> call(Account account, Album album) async {
    _log.info("[call] Resync album: ${album.name}");
    if (album.provider is! AlbumStaticProvider) {
      throw ArgumentError(
          "Resync only make sense for static albums: ${album.name}");
    }
    final items = AlbumStaticProvider.of(album).items;

    final files = await FindFile(_c)(
      account,
      items
          .whereType<AlbumFileItem>()
          .map((i) => i.file.fileId)
          .whereNotNull()
          .toList(),
      onFileNotFound: (_) {},
    );
    final fileIt = files.iterator;
    var nextFile = fileIt.moveNext() ? fileIt.current : null;
    return items.map((i) {
      if (i is AlbumFileItem) {
        try {
          if (i.file.fileId! == nextFile?.fileId) {
            final newItem = i.copyWith(
              file: nextFile,
            );
            nextFile = fileIt.moveNext() ? fileIt.current : null;
            return newItem;
          } else {
            _log.warning("[call] File not found: ${logFilename(i.file.path)}");
            return i;
          }
        } catch (e, stackTrace) {
          _log.shout(
              "[call] Failed syncing file in album: ${logFilename(i.file.path)}",
              e,
              stackTrace);
          return i;
        }
      } else {
        return i;
      }
    }).toList();
  }

  final DiContainer _c;
}
