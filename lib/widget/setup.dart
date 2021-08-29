import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/pref.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/widget/home.dart';
import 'package:nc_photos/widget/sign_in.dart';
import 'package:page_view_indicators/circle_page_indicator.dart';

bool isNeedSetup() =>
    Pref.inst().getSetupProgressOr() & _PageId.all != _PageId.all;

class Setup extends StatefulWidget {
  static const routeName = "/setup";

  @override
  createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  @override
  build(BuildContext context) {
    return AppTheme(
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: Builder(builder: (context) => _buildContent(context)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(L10n.global().setupWidgetTitle),
      elevation: 0,
    );
  }

  Widget _buildContent(BuildContext context) {
    final page = _pageController.hasClients ? _pageController.page!.round() : 0;
    final pages = <Widget>[
      if (_initialProgress & _PageId.exif == 0) _Exif(),
      if (_initialProgress & _PageId.hiddenPrefDirNotice == 0)
        _HiddenPrefDirNotice(),
    ];
    final isLastPage = page >= pages.length - 1;
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            children: pages,
            onPageChanged: (page) {
              setState(() {
                _currentPageNotifier.value = page;
              });
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: isLastPage
                    ? [
                        ElevatedButton(
                          onPressed: _onDonePressed,
                          child: Text(L10n.global().doneButtonLabel),
                        ),
                      ]
                    : [
                        ElevatedButton(
                          onPressed: () {
                            if (_pageController.hasClients) {
                              _onNextPressed(
                                  (pages[_pageController.page!.round()]
                                          as _Page)
                                      .getPageId());
                            }
                          },
                          child: Text(L10n.global().nextButtonLabel),
                        ),
                      ],
              ),
              CirclePageIndicator(
                itemCount: pages.length,
                currentPageNotifier: _currentPageNotifier,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onDonePressed() {
    Pref.inst().setSetupProgress(_PageId.all);

    final account = Pref.inst().getCurrentAccount();
    if (account == null) {
      Navigator.pushReplacementNamed(context, SignIn.routeName);
    } else {
      Navigator.pushReplacementNamed(context, Home.routeName,
          arguments: HomeArguments(account));
    }
  }

  void _onNextPressed(int pageId) {
    Pref.inst().setSetupProgress(Pref.inst().getSetupProgressOr() | pageId);
    _pageController.nextPage(
        duration: k.animationDurationNormal, curve: Curves.easeInOut);
  }

  final _initialProgress = Pref.inst().getSetupProgressOr();
  final _pageController = PageController();
  var _currentPageNotifier = ValueNotifier<int>(0);
}

class _PageId {
  static const exif = 0x01;
  static const hiddenPrefDirNotice = 0x02;
  static const all = exif | hiddenPrefDirNotice;
}

abstract class _Page {
  int getPageId();
}

class _Exif extends StatefulWidget implements _Page {
  @override
  createState() => _ExifState();

  @override
  getPageId() => _PageId.exif;
}

class _ExifState extends State<_Exif> {
  @override
  build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(L10n.global().settingsExifSupportTitle),
            value: _isEnableExif,
            onChanged: _onValueChanged,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(L10n.global().exifSupportDetails),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(L10n.global().setupSettingsModifyLaterHint,
                style: Theme.of(context)
                    .textTheme
                    .bodyText2!
                    .copyWith(fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _onValueChanged(bool value) {
    Pref.inst().setEnableExif(value);
    setState(() {
      _isEnableExif = value;
    });
  }

  bool _isEnableExif = Pref.inst().isEnableExifOr();
}

class _HiddenPrefDirNotice extends StatefulWidget implements _Page {
  @override
  createState() => _HiddenPrefDirNoticeState();

  @override
  getPageId() => _PageId.hiddenPrefDirNotice;
}

class _HiddenPrefDirNoticeState extends State<_HiddenPrefDirNotice> {
  @override
  build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(L10n.global().setupHiddenPrefDirNoticeDetail),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              "assets/setup_hidden_pref_dir.png",
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
