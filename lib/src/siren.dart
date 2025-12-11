import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

import './entities/siren_store_response.dart';
import './entities/siren_store_service.dart';
import './services/siren_apple_app_store.dart';
import './services/siren_google_play_store.dart';

/// This class allows you to check the application store for new versions of your app.
class Siren {
  SirenStoreResponse _response = SirenStoreResponse(version: '', package: '', url: '');

  static SirenStoreService _getStoreClient() {
    if (Platform.isAndroid) {
      return SirenGooglePlayStore();
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return SirenAppleAppStore();
    }

    throw UnimplementedError('This lib only supports Android, iOS and MacOS');
  }

  /// This method will get the local version downloaded of your app.
  Future<Version> get storeVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    _response = await _getStoreClient().getStoreResponse(from: packageInfo.packageName);
    return Version.parse(_response.version);
  }

  /// This method will get the store version of your app.
  Future<Version> get localVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    return Version.parse(currentVersion);
  }

  /// This method checks for an update in the application store and returns if there is a newer version than the local one.
  Future<bool> updateIsAvailable() async {
    final localVer = await localVersion;
    final storeVer = await storeVersion;

    return storeVer > localVer;
  }

  Future<void> promptUpdateV2(BuildContext context,
      {String title = 'Update Available',
      String message = '''
There is an updated version available on the App Store. Would you like to upgrade?''',
      String buttonUpgradeText = 'Upgrade',
      String buttonCancelText = 'Cancel',
      bool forceUpgrade = false}) async {
    try {
      final isUpdateAvailable = await updateIsAvailable();
      if (!isUpdateAvailable) {
        return;
      }
      if (context.mounted) {
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final buttons = <Widget>[];

            if (!forceUpgrade) {
              buttons.add(TextButton(
                child: Text(buttonCancelText),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ));
            }

            buttons.add(TextButton(
              child: Text(buttonUpgradeText),
              onPressed: () async {
                await launchStore(_response.url);

                if (!forceUpgrade) {
                  Navigator.of(context).pop();
                }
              },
            ));

            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: buttons,
            );
          },
        );
      }
    } catch (e) {
      return;
    }
  }

  /// custom update dialog
  /// 使用方式：Siren().promptUpdateWithCustomUI(context, builder: (context, response) {
  /// return Container(
  ///   width: 150.sr,
  ///   height: 300.sr,
  ///   decoration: BoxDecoration(color: AppColors.errorDark, borderRadius: BorderRadius.circular(20.sr)),
  ///   child: Column(
  ///     children: [
  ///       Text(response.version),
  ///       Text(response.url),
  ///       ElevatedButton(onPressed: () {
  /// final url = response.url;
  ///  if (url != '' && await canLaunch(url)) {
  ///    await launch(url, forceSafariVC: false);
  ///  }
  /// }, child: const Text('升级')),
  ///     ],
  ///   ),
  /// });
  Future<void> promptUpdateWithCustomUI(BuildContext context,
      {required Widget Function(BuildContext, SirenStoreResponse) builder}) async {
    try {
      final isUpdateAvailable = await updateIsAvailable();
      if (!isUpdateAvailable) {
        return;
      }

      if (context.mounted) {
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Center(
              child: Material(
                type: MaterialType.transparency,
                child: builder(context, _response),
              ),
            );
          },
        );
      }
    } catch (e) {
      return;
    }
  }

  Future<void> launchStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // 对应旧的 canLaunch
      await launchUrl(uri, mode: LaunchMode.externalApplication); // 对应 forceSafariVC: false
    } else {
      throw Exception('Could not launch $url');
    }
  }

  /// This method shows an customizable AlertDialog if an update is available.
  Future<void> promptUpdate(BuildContext context,
      {String title = 'Update Available',
      String message = '''
There is an updated version available on the App Store. Would you like to upgrade?''',
      String buttonUpgradeText = 'Upgrade',
      String buttonCancelText = 'Cancel',
      bool forceUpgrade = false}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<bool>(
            future: updateIsAvailable(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final buttons = <Widget>[];

                if (!forceUpgrade) {
                  buttons.add(TextButton(
                    child: Text(buttonCancelText),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ));
                }

                buttons.add(TextButton(
                  child: Text(buttonUpgradeText),
                  onPressed: () async {
                    await launchStore(_response.url);

                    if (!forceUpgrade) {
                      Navigator.of(context).pop();
                    }
                  },
                ));

                return AlertDialog(
                  title: Text(title),
                  content: Text(message),
                  actions: buttons,
                );
              }

              return Container();
            });
      },
    );
  }
}
