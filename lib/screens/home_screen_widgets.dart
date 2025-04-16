import 'dart:async';
import 'dart:convert';

import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/clash/clash_http_api.dart';
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/modules/remote_config_manager.dart';
import 'package:clashmi/app/modules/zashboard.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/app_lifecycle_state_notify.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/http_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/app/utils/platform_utils.dart';
import 'package:clashmi/app/utils/websocket.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/about_screen.dart';
import 'package:clashmi/screens/dialog_utils.dart';

import 'package:clashmi/screens/profiles_board_screen.dart';
import 'package:clashmi/screens/proxy_board_screen.dart';
import 'package:clashmi/screens/richtext_viewer.screen.dart';
import 'package:clashmi/screens/settings_screen.dart';
import 'package:clashmi/screens/theme_config.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/webview_helper.dart';
import 'package:clashmi/screens/widgets/segmented_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:libclash_vpn_service/state.dart';

class HomeScreenWidgetPart1 extends StatefulWidget {
  const HomeScreenWidgetPart1({super.key});

  @override
  State<HomeScreenWidgetPart1> createState() => _HomeScreenWidgetPart1();
}

class _HomeScreenWidgetPart1 extends State<HomeScreenWidgetPart1> {
  static final String _kNoSpeed = "↑ 0 B/s   ↓ 0 B/s";
  bool _working = false;
  FlutterVpnServiceState _state = FlutterVpnServiceState.disconnected;
  Timer? _timerStateChecker;

  Websocket? _websocket;

  final ValueNotifier<String> _trafficSpeed = ValueNotifier<String>(_kNoSpeed);
  final ValueNotifier<String> _proxyNow = ValueNotifier<String>("");
  bool _proxyNowUpdating = false;

  @override
  void initState() {
    super.initState();
    VPNService.onEventStateChanged.add(_onStateChanged);
    AppLifecycleStateNofity.onStateResumed(hashCode, _onStateResumed);
    AppLifecycleStateNofity.onStatePaused(hashCode, _onStatePaused);
    ProfileManager.onEventCurrentChanged.add(_onCurrentChanged);
    ProfileManager.onEventUpdate.add(_onUpdate);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    bool running = _state == FlutterVpnServiceState.connected ||
        _state == FlutterVpnServiceState.connecting ||
        _state == FlutterVpnServiceState.disconnecting ||
        _state == FlutterVpnServiceState.reasserting;
    bool started = _state == FlutterVpnServiceState.connected;
    final currentProfile = ProfileManager.getCurrent();
    var widgets = [
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: running ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    )),
                SizedBox(
                  width: 10,
                ),
                Text(
                  running
                      ? tcontext.meta.connected
                      : tcontext.meta.disconnected,
                  textAlign: TextAlign.left,
                ),
              ]),
              Stack(children: [
                SizedBox(
                  width: 60,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: Switch.adaptive(
                      value: _state == FlutterVpnServiceState.connected,
                      onChanged: currentProfile == null
                          ? null
                          : (bool value) async {
                              if (_working ||
                                  _state == FlutterVpnServiceState.connecting ||
                                  _state ==
                                      FlutterVpnServiceState.disconnecting ||
                                  _state ==
                                      FlutterVpnServiceState.reasserting) {
                                return;
                              }
                              _working = true;

                              if (value) {
                                var err = await VPNService.start(
                                    currentProfile.id,
                                    const Duration(seconds: 20));
                                if (!context.mounted) {
                                  return;
                                }
                                if (err != null) {
                                  DialogUtils.showAlertDialog(
                                      context, err.message);
                                }
                              } else {
                                await VPNService.stop();
                              }
                              _working = false;
                              setState(() {});
                            },
                    ),
                  ),
                ),
                Positioned(
                    left: 8,
                    top: 12,
                    child: SizedBox(
                        width: 25,
                        height: 25,
                        child: _working ||
                                _state == FlutterVpnServiceState.connecting ||
                                _state ==
                                    FlutterVpnServiceState.disconnecting ||
                                _state == FlutterVpnServiceState.reasserting
                            ? const RepaintBoundary(
                                child: CircularProgressIndicator(
                                    color: ThemeDefine.kColorGreenBright))
                            : null)),
              ]),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            ValueListenableBuilder<String>(
              builder: _buildWithTrafficSpeedValue,
              valueListenable: _trafficSpeed,
            ),
          ]),
          SizedBox(
            height: 10,
          ),
        ],
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
        height: 70,
        child: SegmentedElevatedButton(
          segments: [
            SegemntedElevatedButtonItem(
                value: ClashConfigsMode.rule.index, text: tcontext.meta.rule),
            SegemntedElevatedButtonItem(
                value: ClashConfigsMode.global.index,
                text: tcontext.meta.global),
            SegemntedElevatedButtonItem(
                value: ClashConfigsMode.direct.index,
                text: tcontext.outboundRuleMode.direct)
          ],
          selected: ClashSettingManager.getConfigsMode().index,
          padding: const EdgeInsets.fromLTRB(0, 3, 0, 3),
          onPressed: (int value) async {
            ClashConfigsMode type = ClashConfigsMode.values[value];
            var error = await ClashSettingManager.setConfigsMode(type);
            if (!context.mounted) {
              return;
            }
            if (error != null) {
              DialogUtils.showAlertDialog(context, error.message);
              return;
            }
            _updateProxyNow();
          },
        ),
      ),
      ListTile(
        title: Text(tcontext.meta.myProfiles),
        subtitle: currentProfile == null
            ? Text("")
            : Text(currentProfile.getShowName()),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 20,
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  settings: ProfilesBoardScreen.routSettings(),
                  builder: (context) => ProfilesBoardScreen()));
          setState(() {});
        },
      ),
    ];

    if (started) {
      widgets.add(ListTile(
        title: Text(tcontext.meta.proxy),
        subtitle: ValueListenableBuilder<String>(
          builder: _buildWithValue,
          valueListenable: _proxyNow,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 20,
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  settings: ProxyBoardScreen.routSettings(),
                  builder: (context) => ProxyBoardScreen()));
          _updateProxyNow();
        },
      ));

      widgets.add(ListTile(
        title: Text(tcontext.meta.board),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 20,
        onTap: () async {
          ReturnResultError? err = await Zashboard.start();
          if (err != null) {
            if (!context.mounted) {
              return;
            }
            DialogUtils.showAlertDialog(context, err.message);
            return;
          }
          String url = await Zashboard.getUrl();
          if (!context.mounted) {
            return;
          }
          await WebviewHelper.loadUrl(context, url, "board",
              title: tcontext.meta.board, inappWebViewOpenExternal: false);
          if (PlatformUtils.isMobile()) {
            await Zashboard.stop();
          }
        },
      ));
    }
    return Card(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (_, index) {
          return widgets[index];
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(
            height: 1,
            thickness: 0.3,
          );
        },
        itemCount: widgets.length,
      ),
    ));
  }

  Widget _buildWithTrafficSpeedValue(
      BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: ThemeConfig.kFontSizeListSubItem),
      ),
    );
  }

  Widget _buildWithValue(BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        textAlign: TextAlign.start,
      ),
    );
  }

  Future<void> _onStateChanged(
      FlutterVpnServiceState state, Map<String, String> params) async {
    if (_state == state) {
      return;
    }
    //print("_onStateChanged $_state->$state");
    _state = state;
    if (state == FlutterVpnServiceState.disconnected) {
      _disconnectToTraffic();
    } else if (state == FlutterVpnServiceState.connecting) {
    } else if (state == FlutterVpnServiceState.connected) {
      if (!AppLifecycleStateNofity.isPaused()) {
        _connectToTraffic();
      }
    } else if (state == FlutterVpnServiceState.reasserting) {
      _disconnectToTraffic();
    } else if (state == FlutterVpnServiceState.disconnecting) {
      _stopStateCheckTimer();

      Zashboard.stop();
    } else {
      _disconnectToTraffic();
    }

    setState(() {});
  }

  Future<void> _onStateResumed() async {
    _checkState();
    _startStateCheckTimer();
  }

  Future<void> _onStatePaused() async {
    _stopStateCheckTimer();
  }

  Future<void> _onCurrentChanged(String id) async {
    if (id.isEmpty) {
      await VPNService.stop();
      return;
    }

    final err = await VPNService.restart(id, const Duration(seconds: 20));
    if (err != null) {
      if (!mounted) {
        return;
      }
      DialogUtils.showAlertDialog(context, err.message);
    }
  }

  Future<void> _onUpdate(String id, bool finish) async {}
  Future<void> _checkState() async {
    var state = await VPNService.getState();
    await _onStateChanged(state, {});
  }

  void _startStateCheckTimer() {
    const Duration duration = Duration(seconds: 1);
    _timerStateChecker ??= Timer.periodic(duration, (timer) async {
      if (AppLifecycleStateNofity.isPaused()) {
        return;
      }
      await _checkState();
    });
  }

  void _stopStateCheckTimer() {
    _timerStateChecker?.cancel();
    _timerStateChecker = null;
  }

  Future<void> _connectToTraffic() async {
    bool started = await VPNService.getStarted();
    if (!started) {
      return;
    }
    if (AppLifecycleStateNofity.isPaused()) {
      return;
    }

    _websocket ??= Websocket(
        url: await ClashHttpApi.getTrafficUrl(),
        userAgent: await HttpUtils.getUserAgent(),
        onMessage: (String message) {
          if (AppLifecycleStateNofity.isPaused()) {
            Future.delayed(const Duration(seconds: 0), () async {
              _disconnectToTraffic();
            });
            return;
          }
          var obj = jsonDecode(message);
          ClashTraffic traffic = ClashTraffic();
          traffic.fromJson(obj);
          final trafficSpeedNotify =
              "↑ ${ClashHttpApi.convertTrafficToStringDouble(traffic.upload)}/s  ↓ ${ClashHttpApi.convertTrafficToStringDouble(traffic.download)}/s";
          _trafficSpeed.value = trafficSpeedNotify;

          final duration = Duration(seconds: _proxyNow.value.isEmpty ? 1 : 5);
          Future.delayed(duration, () async {
            _updateProxyNow();
          });
        },
        onDone: () {
          _disconnectToTraffic();
        },
        onError: (err) {
          _disconnectToTraffic();
        });
    await _websocket!.connect();
  }

  Future<void> _disconnectToTraffic() async {
    await _websocket?.disconnect();

    _trafficSpeed.value = _kNoSpeed;
    _proxyNow.value = "";
  }

  Future<void> _updateProxyNow() async {
    if (_state == FlutterVpnServiceState.connected) {
      if (AppLifecycleStateNofity.isPaused()) {
        return;
      }
      if (_proxyNowUpdating) {
        return;
      }
      _proxyNowUpdating = true;
      final result = await ClashHttpApi.getNowProxy(
          ClashSettingManager.getConfig().Mode ?? ClashConfigsMode.rule.name);
      if (result.error != null || result.data!.isEmpty) {
        _proxyNow.value = "";
      } else {
        if (result.data!.length >= 2) {
          if (result.data!.first.delay != null) {
            _proxyNow.value =
                "${result.data![1].name} -> ${result.data!.first.name} (${result.data!.first.delay} ms)";
          } else {
            _proxyNow.value =
                "${result.data![1].name} -> ${result.data!.first.name}";
          }
        } else {
          if (result.data!.first.delay != null) {
            _proxyNow.value =
                "${result.data!.first.name} (${result.data!.first.delay} ms)";
          } else {
            _proxyNow.value = result.data!.first.name;
          }
        }
      }
      _proxyNowUpdating = false;
    } else {
      _proxyNow.value = "";
    }
  }
}

class HomeScreenWidgetPart2 extends StatelessWidget {
  const HomeScreenWidgetPart2({super.key});

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    var widgets = [
      ListTile(
        title: Text(tcontext.meta.settingApp),
        leading: Icon(
          Icons.settings,
          size: 20,
        ),
        minLeadingWidth: 40,
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await showAppSettings(context);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.settingCore),
        leading: Icon(
          Icons.settings,
          size: 20,
        ),
        minLeadingWidth: 40,
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await showClashSettings(context);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.coreLog),
        leading: Icon(
          Icons.set_meal,
          size: 20,
        ),
        minLeadingWidth: 40,
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          String content = "";
          final filePath = await PathUtils.serviceLogFilePath();
          final item =
              await FileUtils.readAsStringReverse(filePath, 10 * 1024, false);
          if (item != null) {
            content = item.item1;
          }
          if (!context.mounted) {
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  settings: RichtextViewScreen.routSettings(),
                  builder: (context) => RichtextViewScreen(
                      title: tcontext.meta.coreLog,
                      file: "",
                      content: content)));
        },
      ),
      ListTile(
        title: Text(tcontext.meta.help),
        leading: Icon(
          Icons.help,
          size: 20,
        ),
        minLeadingWidth: 40,
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          var remoteConfig = RemoteConfigManager.getConfig();
          await WebviewHelper.loadUrl(
              context, remoteConfig.telegram, tcontext.meta.help);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.about),
        leading: Icon(
          Icons.info,
          size: 20,
        ),
        minLeadingWidth: 40,
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  settings: AboutScreen.routSettings(),
                  builder: (context) => AboutScreen()));
        },
      )
    ];

    return Card(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (_, index) {
          return widgets[index];
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(
            height: 1,
            thickness: 0.3,
          );
        },
        itemCount: widgets.length,
      ),
    ));
  }
}
