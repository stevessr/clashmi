// ignore_for_file: unused_catch_stack, empty_catches

import 'package:clashmi/app/modules/remote_config_manager.dart';
import 'package:clashmi/app/utils/url_launcher_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/group_item_options.dart';
import 'package:clashmi/screens/webview_helper.dart';
import 'package:flutter/material.dart';

class GroupOptionsHelper {
  static List<GroupItemOptions> getOutlinkOptions(
      BuildContext context, String from) {
    final tcontext = Translations.of(context);
    var remoteConfig = RemoteConfigManager.getConfig();

    List<GroupItemOptions> options = [];
    options.addAll([
      remoteConfig.faq.isNotEmpty
          ? GroupItemOptions(
              pushOptions: GroupItemPushOptions(
                  name: tcontext.meta.faq,
                  onPush: () async {
                    String url =
                        await UrlLauncherUtils.reorganizationUrlWithAnchor(
                            remoteConfig.faq);
                    if (!context.mounted) {
                      return;
                    }
                    await WebviewHelper.loadUrl(context, url, "SSS_faq",
                        title: tcontext.meta.faq);
                  }))
          : GroupItemOptions(),
    ]);
    return options;
  }
}
