import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/album/cover_provider.dart';
import 'package:nc_photos/entity/album/provider.dart';
import 'package:nc_photos/entity/album/sort_provider.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/use_case/create_album.dart';
import 'package:nc_photos/widget/album_dir_picker.dart';

/// Dialog to create a new album
///
/// The created album will be popped to the previous route, or null if user
/// cancelled
class NewAlbumDialog extends StatefulWidget {
  NewAlbumDialog({
    Key? key,
    required this.account,
    this.isAllowDynamic = true,
  }) : super(key: key);

  @override
  createState() => _NewAlbumDialogState();

  final Account account;
  final bool isAllowDynamic;
}

class _NewAlbumDialogState extends State<NewAlbumDialog> {
  @override
  initState() {
    super.initState();
  }

  @override
  build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      child: AlertDialog(
        title: Text(L10n.of(context).createAlbumTooltip),
        content: Form(
          key: _formKey,
          child: Container(
            constraints: BoxConstraints.tightFor(width: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    hintText: L10n.of(context).nameInputHint,
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return L10n.of(context).albumNameInputInvalidEmpty;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _formValue.name = value!;
                  },
                ),
                if (widget.isAllowDynamic) ...[
                  DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<_Provider>(
                      value: _provider,
                      items: [_Provider.static, _Provider.dir]
                          .map((e) => DropdownMenuItem<_Provider>(
                                value: e,
                                child: Text(e.toValueString(context)),
                              ))
                          .toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _provider = newValue!;
                        });
                      },
                      onSaved: (value) {
                        _formValue.provider = value;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _provider.toDescription(context),
                    style: Theme.of(context).textTheme.bodyText2,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _onOkPressed(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  void _onOkPressed(BuildContext context) {
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState!.save();
      if (_formValue.provider == _Provider.static ||
          _formValue.provider == null) {
        _onConfirmStaticAlbum();
      } else {
        _onConfirmDirAlbum();
      }
    }
  }

  void _onConfirmStaticAlbum() {
    final album = Album(
      name: _formValue.name,
      provider: AlbumStaticProvider(
        items: const [],
      ),
      coverProvider: AlbumAutoCoverProvider(),
      sortProvider: AlbumTimeSortProvider(isAscending: false),
    );
    _log.info("[_onOkPressed] Creating static album: $album");
    final albumRepo = AlbumRepo(AlbumCachedDataSource());
    final newAlbum = CreateAlbum(albumRepo)(widget.account, album);
    // let previous route to handle this future
    Navigator.of(context).pop(newAlbum);
  }

  void _onConfirmDirAlbum() {
    setState(() {
      _isVisible = false;
    });
    Navigator.of(context)
        .pushNamed<List<File>>(AlbumDirPicker.routeName,
            arguments: AlbumDirPickerArguments(widget.account))
        .then((value) {
      if (value == null) {
        Navigator.of(context).pop();
        return;
      }

      final album = Album(
        name: _formValue.name,
        provider: AlbumDirProvider(
          dirs: value,
        ),
        coverProvider: AlbumAutoCoverProvider(),
        sortProvider: AlbumTimeSortProvider(isAscending: false),
      );
      _log.info("[_onOkPressed] Creating dir album: $album");
      final albumRepo = AlbumRepo(AlbumCachedDataSource());
      final newAlbum = CreateAlbum(albumRepo)(widget.account, album);
      // let previous route to handle this future
      Navigator.of(context).pop(newAlbum);
    }).catchError((e, stacktrace) {
      _log.shout("[_onOkPressed] Failed while pushNamed", e, stacktrace);
      Navigator.of(context).pop();
    });
  }

  final _formKey = GlobalKey<FormState>();
  var _provider = _Provider.static;

  final _formValue = _FormValue();

  var _isVisible = true;

  static final _log = Logger("widget.new_album_dialog._NewAlbumDialogState");
}

class _FormValue {
  late String name;
  _Provider? provider;
}

enum _Provider {
  static,
  dir,
}

extension on _Provider {
  String toValueString(BuildContext context) {
    switch (this) {
      case _Provider.static:
        return L10n.of(context).createAlbumDialogBasicLabel;

      case _Provider.dir:
        return L10n.of(context).createAlbumDialogFolderBasedLabel;

      default:
        throw StateError("Unknown value: $this");
    }
  }

  String toDescription(BuildContext context) {
    switch (this) {
      case _Provider.static:
        return L10n.of(context).createAlbumDialogBasicDescription;

      case _Provider.dir:
        return L10n.of(context).createAlbumDialogFolderBasedDescription;

      default:
        throw StateError("Unknown value: $this");
    }
  }
}
