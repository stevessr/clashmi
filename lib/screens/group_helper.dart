// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';

import 'package:clashmi/app/modules/remote_config.dart';
import 'package:clashmi/app/modules/remote_config_manager.dart';
import 'package:clashmi/app/utils/url_launcher_utils.dart';
import 'package:clashmi/screens/inapp_webview_screen.dart';
import 'package:flutter/material.dart';

class GroupHelper {
  static Future<void> showAddProfile(
      BuildContext context, bool popGetProfile) async {}

  static Future<void> onTapGetProfile(
      BuildContext context, String title, String url, String ispId) async {
    Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    var remoteConfig = RemoteConfigManager.getConfig();
    if (RemoteConfig.isSelfHost(url, remoteConfig.host)) {
      url = await UrlLauncherUtils.reorganizationUrlWithAnchor(url);
    }

    if (!context.mounted) {
      return;
    }
    await InAppWebViewScreen.makeSureEnvironmentCreated();
    if (!context.mounted) {
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: InAppWebViewScreen.routSettings("get_profile"),
            builder: (context) => InAppWebViewScreen(
                  title: title,
                  url: url,
                  showGoBackGoForward: true,
                  setJSWindowObject: true,
                )));
  }
}
