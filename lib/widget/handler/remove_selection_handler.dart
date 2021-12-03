import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/debug_util.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/snack_bar_manager.dart';
import 'package:nc_photos/use_case/remove.dart';

class RemoveSelectionHandler {
  /// Remove [selectedFiles] and return the removed count
  Future<int> call({
    required Account account,
    required List<File> selectedFiles,
    bool shouldCleanupAlbum = true,
    bool isRemoveOpened = false,
  }) async {
    final String processingText, successText;
    final String Function(int) failureText;
    if (isRemoveOpened) {
      processingText = L10n.global().deleteProcessingNotification;
      successText = L10n.global().deleteSuccessNotification;
      failureText = (_) => L10n.global().deleteFailureNotification;
    } else {
      processingText = L10n.global()
          .deleteSelectedProcessingNotification(selectedFiles.length);
      successText = L10n.global().deleteSelectedSuccessNotification;
      failureText =
          (count) => L10n.global().deleteSelectedFailureNotification(count);
    }
    SnackBarManager().showSnackBar(
      SnackBar(
        content: Text(processingText),
        duration: k.snackBarDurationShort,
      ),
      canBeReplaced: true,
    );

    var failureCount = 0;
    await Remove(KiwiContainer().resolve<DiContainer>())(
      account,
      selectedFiles,
      onRemoveFileFailed: (file, e, stackTrace) {
        _log.shout(
            "[call] Failed while removing file: ${logFilename(file.path)}",
            e,
            stackTrace);
        ++failureCount;
      },
      shouldCleanUp: shouldCleanupAlbum,
    );
    if (failureCount == 0) {
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(successText),
        duration: k.snackBarDurationNormal,
      ));
    } else {
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(failureText(failureCount)),
        duration: k.snackBarDurationNormal,
      ));
    }
    return selectedFiles.length - failureCount;
  }

  static final _log =
      Logger("widget.handler.remove_selection_handler.RemoveSelectionHandler");
}
