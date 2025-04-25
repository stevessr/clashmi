import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/app_scheme_actions.dart';
import 'package:clashmi/app/utils/platform_utils.dart';
import 'package:clashmi/app/utils/system_scheme_utils.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class SchemeHandler {
  static void Function(bool)? vpnConnect;
  static void Function(bool)? vpnDisconnect;
  static void Function(bool)? vpnReconnect;
  static Future<ReturnResultError?> handle(
      BuildContext context, String url) async {
    //clash://install-config?url=trojan://41bec492-cd79-4b57-9a15-7d2bb00fcfca@163.123.192.57:443?allowInsecure=1#%F0%9F%87%BA%F0%9F%87%B8%20_US_%E7%BE%8E%E5%9B%BD|trojan://a8f54f4e-1d9d-44e4-9ef7-50ee7ba89561@jk.jkk.kisskiss.pro:1887?allowInsecure=1#%F0%9F%87%B0%F0%9F%87%B7%20_KR_%E9%9F%A9%E5%9B%BD
    //clashmi://install-config?url=https://xxxxx.com/clash/config
    //clashmi://connect?background=false
    //clashmi://disconnect?background=false
    //clashmi://reconnect?background=false
    //clashmi://install-config?url=xxx&name=xxx&&isp-name=xxx&isp-code=xxx;connect; disconnect; reconnect;
    //clashmi://install-config?url=https%3A%2F%2Fxn--xxxxx.com%2Fsub%2Fa363e83fd1f559df%2Fclash&name=gdy&&isp-name=%E8%B7%9F%E6%96%97%E4%BA%91&isp-code=https%3A%2F%2Fxn--9kq147c4p2a.com%2Fuser
    //clashmi://restore-backup?url=https%3A%2F%2Fxn--xxxxx.com%2Fsub%2Fa363e83fd1f559df%2Fclash
    Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return ReturnResultError("parse url failed: $url");
    }
    if (uri.isScheme(SystemSchemeUtils.getClashScheme())) {
      if (uri.host == "install-config") {
        return await _installConfig(context, uri);
      }
    }
    return ReturnResultError("unsupport scheme: ${uri.scheme}");
  }

  static Future<ReturnResultError?> _installConfig(
      BuildContext context, Uri uri) async {
    if (PlatformUtils.isPC()) {
      await windowManager.show();
    }
    String? name;
    String? url;

    if (!context.mounted) {
      return null;
    }
    try {
      name = uri.queryParameters["name"];
      url = uri.queryParameters["url"];
    } catch (err) {
      DialogUtils.showAlertDialog(context, err.toString(),
          showCopy: true, showFAQ: true, withVersion: true);
      return ReturnResultError(err.toString());
    }
    name ??= uri.fragment;
    if (name.isNotEmpty) {
      try {
        name = Uri.decodeComponent(name);
      } catch (err) {}
    }
    if (url != null) {
      try {
        url = Uri.decodeComponent(url);
      } catch (err) {}
    }

    if (url == null || url.isEmpty) {
      return ReturnResultError("url empty");
    }

    if (!context.mounted) {
      return null;
    }
    ReturnResultError? result =
        await addConfigBySubscriptionLink(context, url, name, false);

    return result;
  }

  static Future<ReturnResultError?> addConfigBySubscriptionLink(
      BuildContext context,
      String urlOrContent,
      String? name,
      bool autoAdd) async {
    return null;
  }
}
