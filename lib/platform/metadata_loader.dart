import 'package:exifdart/exifdart.dart';
import 'package:flutter/foundation.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/entity/file.dart';

abstract class MetadataLoader {
  /// Load metadata for [file] from cache
  ///
  /// If the file is not found in cache after a certain amount of time, an
  /// exception will be thrown
  Future<Map<String, dynamic>> loadCacheFile(Account account, File file);

  /// Download and load metadata for [file]
  ///
  /// This function will always try to download the file, no matter it's cached
  /// or not
  Future<Map<String, dynamic>> loadNewFile(Account account, File file);

  /// Load metadata for [file], either from cache or a new download
  Future<Map<String, dynamic>> loadFile(Account account, File file);

  void cancel();

  @protected
  static Future<Map<String, dynamic>> loadMetadata({
    AbstractBlobReader Function() exifdartReaderBuilder,
    AsyncImageInput Function() imageSizeGetterInputBuilder,
  }) async {
    final metadata = await readMetadata(exifdartReaderBuilder());
    int imageWidth, imageHeight;
    if (metadata.imageWidth == null || metadata.imageHeight == null) {
      final resolution =
          await AsyncImageSizeGetter.getSize(imageSizeGetterInputBuilder());
      imageWidth = resolution.width;
      imageHeight = resolution.height;
    } else {
      if (metadata.rotateAngleCcw != null &&
          metadata.rotateAngleCcw % 180 != 0) {
        imageWidth = metadata.imageHeight;
        imageHeight = metadata.imageWidth;
      } else {
        imageWidth = metadata.imageWidth;
        imageHeight = metadata.imageHeight;
      }
    }
    return {
      if (metadata.exif != null) "exif": metadata.exif,
      if (imageWidth > 0 && imageHeight > 0)
        "resolution": {
          "width": imageWidth,
          "height": imageHeight,
        },
    };
  }
}
