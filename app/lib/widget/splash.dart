import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/mobile/android/activity.dart';
import 'package:nc_photos/platform/k.dart' as platform_k;
import 'package:nc_photos/pref.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/update_checker.dart';
import 'package:nc_photos/use_case/compat/v29.dart';
import 'package:nc_photos/use_case/compat/v46.dart';
import 'package:nc_photos/widget/changelog.dart';
import 'package:nc_photos/widget/home.dart';
import 'package:nc_photos/widget/setup.dart';
import 'package:nc_photos/widget/sign_in.dart';

class Splash extends StatefulWidget {
  static const routeName = "/splash";

  const Splash({
    Key? key,
  }) : super(key: key);

  @override
  createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doWork();
    });
  }

  Future<void> _doWork() async {
    if (Pref().getFirstRunTime() == null) {
      await Pref().setFirstRunTime(DateTime.now().millisecondsSinceEpoch);
    }
    if (_shouldUpgrade()) {
      setState(() {
        _isUpgrading = true;
      });
      unawaited(Pref().setIsAutoUpdateCheckAvailable(false));
      await _handleUpgrade();
      setState(() {
        _isUpgrading = false;
      });
    }
    unawaited(_exit());
    if (Pref().isEnableAutoUpdateCheckOr()) {
      unawaited(const AutoUpdateChecker()());
    }
  }

  @override
  build(BuildContext context) {
    return AppTheme(
      child: Scaffold(
        body: WillPopScope(
          onWillPop: () => Future.value(false),
          child: Builder(builder: (context) => _buildContent(context)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  L10n.global().appTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headline4,
                ),
              ],
            ),
            if (_isUpgrading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: Column(
                  children: const [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                    SizedBox(height: 8),
                    Text("Updating"),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exit() async {
    _log.info("[_exit]");
    final account = Pref().getCurrentAccount();
    if (isNeedSetup()) {
      unawaited(Navigator.pushReplacementNamed(context, Setup.routeName));
    } else if (account == null) {
      unawaited(Navigator.pushReplacementNamed(context, SignIn.routeName));
    } else {
      unawaited(
        Navigator.pushReplacementNamed(context, Home.routeName,
            arguments: HomeArguments(account)),
      );
      if (platform_k.isAndroid) {
        final initialRoute = await Activity.consumeInitialRoute();
        if (initialRoute != null) {
          unawaited(Navigator.pushNamed(context, initialRoute));
        }
      }
    }
  }

  bool _shouldUpgrade() {
    final lastVersion = Pref().getLastVersionOr(k.version);
    return lastVersion < k.version;
  }

  Future<void> _handleUpgrade() async {
    try {
      final lastVersion = Pref().getLastVersionOr(k.version);
      unawaited(_showChangelogIfAvailable(lastVersion));
      // begin upgrade while showing the changelog
      try {
        _log.info("[_handleUpgrade] Upgrade: $lastVersion -> ${k.version}");
        await _upgrade(lastVersion);
        _log.info("[_handleUpgrade] Upgrade done");
      } finally {
        // ensure user has closed the changelog
        await _changelogCompleter.future;
      }
    } catch (e, stackTrace) {
      _log.shout("[_handleUpgrade] Failed while upgrade", e, stackTrace);
    } finally {
      await Pref().setLastVersion(k.version);
    }
  }

  Future<void> _upgrade(int lastVersion) async {
    if (lastVersion < 290) {
      await _upgrade29(lastVersion);
    }
    if (lastVersion < 460) {
      await _upgrade46(lastVersion);
    }
  }

  Future<void> _upgrade29(int lastVersion) async {
    try {
      _log.info("[_upgrade29] clearDefaultCache");
      await CompatV29.clearDefaultCache();
    } catch (e, stackTrace) {
      _log.shout("[_upgrade29] Failed while clearDefaultCache", e, stackTrace);
      // just leave the cache then
    }
  }

  Future<void> _upgrade46(int lastVersion) async {
    try {
      _log.info("[_upgrade46] insertDbAccounts");
      final c = KiwiContainer().resolve<DiContainer>();
      await CompatV46.insertDbAccounts(Pref(), c.sqliteDb);
    } catch (e, stackTrace) {
      _log.shout("[_upgrade46] Failed while clearDefaultCache", e, stackTrace);
      unawaited(Pref().setAccounts3(null));
      unawaited(Pref().setCurrentAccountIndex(null));
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: const Text(
              "Failed upgrading app, please sign in to your servers again"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showChangelogIfAvailable(int lastVersion) async {
    if (Changelog.hasContent(lastVersion)) {
      try {
        await Navigator.of(context).pushNamed(Changelog.routeName,
            arguments: ChangelogArguments(lastVersion));
      } catch (e, stackTrace) {
        _log.severe(
            "[_showChangelogIfAvailable] Uncaught exception", e, stackTrace);
      } finally {
        _changelogCompleter.complete();
      }
    } else {
      _changelogCompleter.complete();
    }
  }

  final _changelogCompleter = Completer();
  var _isUpgrading = false;

  static final _log = Logger("widget.splash._SplashState");
}
