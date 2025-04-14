//import 'package:device_info_plus/device_info_plus.dart';

import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/modules/auto_update_manager.dart';
import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/utils/app_lifecycle_state_notify.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/main_channel_utils.dart';

class Biz {
  static final List<void Function()> onEventInitFinish = [];
  static final List<void Function()> onEventInitHomeFinish = [];
  static final List<void Function()> onEventInitAllFinish = [];
  static bool _initFinish = false;
  static bool _initHomeFinish = false;

  static void Function()? onEventExit;
  static void Function(bool)? onEventVPNStateChanged;

  static Future<void> init(bool launchAtStartup) async {
    //await PersistStorage.init();

    await ClashSettingManager.init();
    await ProfileManager.init();
    await VPNService.init();
    MainChannel.init();

    for (var callback in onEventInitFinish) {
      callback();
    }
    _initFinish = true;
    Log.d("initFinish");
    initAllFinish();

    AppLifecycleStateNofity.init();
    AutoUpdateManager.init();
  }

  static Future<void> uninit() async {
    await AutoUpdateManager.uninit();
    AppLifecycleStateNofity.uninit();
    MainChannel.uninit();
    await VPNService.uninit();
    await ProfileManager.uninit();
    await ClashSettingManager.uninit();
  }

  static void clearCache() {
    //PersistStorage.cleanAll();
  }

  static void initHomeFinish() {
    for (var callback in onEventInitHomeFinish) {
      callback();
    }
    _initHomeFinish = true;
    Log.d("initHomeFinish");
    initAllFinish();
  }

  static void initAllFinish() {
    if (_initFinish && _initHomeFinish) {
      Log.d("initAllFinish");
      for (var callback in onEventInitAllFinish) {
        callback();
      }
    }
  }

  static void quit() {
    Future.delayed(const Duration(milliseconds: 10), () {
      if (onEventExit != null) {
        onEventExit!();
      }
    });
  }

  static void vpnStateChanged(bool isConnected) {
    if (onEventVPNStateChanged != null) {
      onEventVPNStateChanged!(isConnected);
    }
  }
}
