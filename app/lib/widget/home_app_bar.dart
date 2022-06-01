import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/event/event.dart';
import 'package:nc_photos/help_utils.dart' as help_utils;
import 'package:nc_photos/pref.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/url_launcher_util.dart';
import 'package:nc_photos/widget/account_picker_dialog.dart';
import 'package:nc_photos/widget/app_bar_circular_progress_indicator.dart';
import 'package:nc_photos/widget/app_bar_title_container.dart';
import 'package:nc_photos/widget/settings.dart';
import 'package:nc_photos/widget/translucent_sliver_app_bar.dart';

/// AppBar for home screens
class HomeSliverAppBar extends StatefulWidget {
  const HomeSliverAppBar({
    Key? key,
    required this.account,
    this.actions,
    this.menuActions,
    this.onSelectedMenuActions,
    this.isShowProgressIcon = false,
  }) : super(key: key);

  @override
  createState() => _HomeSliverAppBarState();

  final Account account;

  /// Screen specific action buttons
  final List<Widget>? actions;

  /// Screen specific actions under the overflow menu. The value of each item
  /// much >= 0
  final List<PopupMenuEntry<int>>? menuActions;
  final void Function(int)? onSelectedMenuActions;
  final bool isShowProgressIcon;
}

class _HomeSliverAppBarState extends State<HomeSliverAppBar> {
  @override
  initState() {
    super.initState();
    _prefUpdatedListener.begin();
  }

  @override
  dispose() {
    _prefUpdatedListener.end();
    super.dispose();
  }

  @override
  build(BuildContext context) {
    final accountLabel = AccountPref.of(widget.account).getAccountLabel();
    return TranslucentSliverAppBar(
      title: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AccountPickerDialog(
              account: widget.account,
            ),
          );
        },
        child: AppBarTitleContainer(
          title: Text(accountLabel ?? widget.account.address),
          subtitle: accountLabel == null ? Text(widget.account.username2) : null,
          icon: widget.isShowProgressIcon
              ? const AppBarCircularProgressIndicator()
              : (widget.account.scheme == "http"
                  ? Icon(
                      Icons.no_encryption_outlined,
                      color: Theme.of(context).colorScheme.error,
                    )
                  : Icon(
                      Icons.https,
                      color: Theme.of(context).colorScheme.primary,
                    )),
        ),
      ),
      scrolledUnderBackgroundColor:
          Theme.of(context).homeNavigationBarBackgroundColor,
      floating: true,
      automaticallyImplyLeading: false,
      actions: (widget.actions ?? []) +
          [
            if (!Pref().isFollowSystemThemeOr(false))
              _DarkModeSwitch(
                onChanged: _onDarkModeChanged,
              ),
            PopupMenuButton<int>(
              icon: Pref().isAutoUpdateCheckAvailableOr()
                  ? Stack(
                      fit: StackFit.passthrough,
                      children: [
                        Icon(Icons.adaptive.more),
                        Positioned.directional(
                          textDirection: Directionality.of(context),
                          end: 0,
                          top: 0,
                          child: const Icon(
                            Icons.circle,
                            color: Colors.red,
                            size: 8,
                          ),
                        ),
                      ],
                    )
                  : null,
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              itemBuilder: (context) =>
                  (widget.menuActions ?? []) +
                  [
                    PopupMenuItem(
                      value: _menuValueAbout,
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Text(L10n.global().settingsMenuLabel),
                          ),
                          if (Pref().isAutoUpdateCheckAvailableOr())
                            Positioned.directional(
                              textDirection: Directionality.of(context),
                              end: 0,
                              top: 0,
                              child: const Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 8,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _menuValueHelp,
                      child: Text(L10n.global().helpTooltip),
                    ),
                  ],
              onSelected: (option) {
                if (option >= 0) {
                  widget.onSelectedMenuActions?.call(option);
                } else {
                  if (option == _menuValueAbout) {
                    Navigator.of(context).pushNamed(Settings.routeName,
                        arguments: SettingsArguments(widget.account));
                  } else if (option == _menuValueHelp) {
                    launch(help_utils.mainUrl);
                  }
                }
              },
            ),
          ],
    );
  }

  void _onDarkModeChanged(bool value) {
    Pref().setDarkTheme(value).then((_) {
      KiwiContainer().resolve<EventBus>().fire(ThemeChangedEvent());
    });
  }

  void _onPrefUpdated(PrefUpdatedEvent ev) {
    if (ev.key == PrefKey.isAutoUpdateCheckAvailable) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  late final _prefUpdatedListener =
      AppEventListener<PrefUpdatedEvent>(_onPrefUpdated);

  static const _menuValueAbout = -1;
  static const _menuValueHelp = -2;
}

class _DarkModeSwitch extends StatelessWidget {
  const _DarkModeSwitch({
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildDarkModeSwitchTheme(context),
      child: Switch(
        value: Theme.of(context).brightness == Brightness.dark,
        onChanged: onChanged,
        activeThumbImage:
            const AssetImage("assets/ic_dark_mode_switch_24dp.png"),
        inactiveThumbImage:
            const AssetImage("assets/ic_dark_mode_switch_24dp.png"),
      ),
    );
  }

  final ValueChanged<bool>? onChanged;
}
