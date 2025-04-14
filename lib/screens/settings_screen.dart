//flclash ProxiesFragment getRawConfigWithId

import 'dart:async';
import 'dart:io';

import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/modules/auto_update_manager.dart';
import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/group_item_creator.dart';
import 'package:clashmi/screens/group_item_options.dart';
import 'package:clashmi/screens/group_screen.dart';
import 'package:clashmi/screens/language_settings_screen.dart';
import 'package:clashmi/screens/list_add_screen.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/themes.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

Future<void> showAppSettings(BuildContext context) async {
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    final tcontext = Translations.of(context);
    var setting = SettingManager.getConfig();
    List<GroupItemOptions> options = [
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.language,
              icon: Icons.language_outlined,
              text: tcontext.locales[setting.languageTag],
              textWidthPercent: 0.5,
              onPush: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: LanguageSettingsScreen.routSettings(),
                        builder: (context) => const LanguageSettingsScreen(
                            canPop: true, canGoBack: true)));
              })),
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.meta.theme,
              selected: setting.ui.theme,
              strings: [
                ThemeDefine.kThemeLight,
                ThemeDefine.kThemeDark,
                ThemeDefine.kThemeSystem
              ],
              onPicker: (String? selected) async {
                if (selected == null) {
                  return;
                }
                setting.ui.theme = selected;

                SettingManager.saveConfig();
                Provider.of<Themes>(context, listen: false)
                    .setTheme(selected, true);
              })),
      AutoUpdateManager.isSupport()
          ? GroupItemOptions(
              stringPickerOptions: GroupItemStringPickerOptions(
                  name: tcontext.meta.updateChannel,
                  selected: setting.autoUpdateChannel,
                  strings: AutoUpdateManager.updateChannels(),
                  onPicker: (String? selected) async {
                    if (selected == null ||
                        setting.autoUpdateChannel == selected) {
                      return;
                    }
                    setting.autoUpdateChannel = selected;

                    AutoUpdateManager.updateChannelChanged();
                  }))
          : GroupItemOptions(),
    ];

    return [
      GroupItem(options: options),
    ];
  }

  final tcontext = Translations.of(context);
  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("appSettings"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.settingApp,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettings(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var appSetting = SettingManager.getConfig();
    var setting = ClashSettingManager.getConfig();
    final logLevels = ClashLogLevel.toList();
    final globalFingerprints = ClashGlobalClientFingerprint.toList();
    List<GroupItemOptions> options00 = [
      GroupItemOptions(
          textOptions: GroupItemTextOptions(
        name: "",
        text: tcontext.meta.coreSettingTips,
        textColor: Colors.green,
        textWidthPercent: 1,
      )),
    ];
    List<GroupItemOptions> options0 = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.coreSettingOverwrite,
              switchValue: appSetting.coreSettingOverwrite,
              onSwitch: (bool value) async {
                appSetting.coreSettingOverwrite = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.externalController,
              text: setting.ExternalController,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                setting.ExternalController = value;
              })),
      GroupItemOptions(
          textOptions: GroupItemTextOptions(
              name: tcontext.meta.secret,
              text: setting.Secret,
              textWidthPercent: 0.5,
              onPush: () async {
                try {
                  await Clipboard.setData(
                      ClipboardData(text: setting.Secret ?? ""));
                } catch (e) {}
              })),
    ];
    List<GroupItemOptions> options = [
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.meta.logLevel,
              selected: logLevels.contains(setting.LogLevel)
                  ? setting.LogLevel
                  : logLevels.last,
              strings: logLevels,
              onPicker: (String? selected) async {
                setting.LogLevel = selected;
              })),
    ];
    List<GroupItemOptions> options1 = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: "IPv6",
              switchValue: setting.IPv6,
              onSwitch: (bool value) async {
                setting.IPv6 = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.tcpConcurrent,
              switchValue: setting.TCPConcurrent,
              onSwitch: (bool value) async {
                setting.TCPConcurrent = value;
              })),
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.meta.globalClientFingerprint,
              selected:
                  globalFingerprints.contains(setting.GlobalClientFingerprint)
                      ? setting.GlobalClientFingerprint
                      : globalFingerprints.first,
              strings: globalFingerprints,
              onPicker: (String? selected) async {
                setting.GlobalClientFingerprint = selected;
              })),
    ];
    List<GroupItemOptions> options2 = [
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.mixedPort,
              text: setting.MixedPort?.toString() ?? "",
              textWidthPercent: 0.5,
              hint: tcontext.meta.required,
              onChanged: (String value) {
                setting.MixedPort = int.tryParse(value);
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.allowLan,
              switchValue: setting.AllowLan,
              onSwitch: (bool value) async {
                setting.AllowLan = value;
                setting.BindAddress = value ? "*" : null;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.allowLanAuthentication,
              text: setting.Authentication?.first,
              hint: "username:password",
              textWidthPercent: 0.5,
              onChanged: (String value) {
                setting.Authentication = value.isEmpty ? null : [value];
              })),
    ];
    List<GroupItemOptions> options3 = [
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.delayTestUrl,
              text: setting.Extension.DelayTestUrl,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                setting.Extension.DelayTestUrl = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.delayTestTimeout,
              text: setting.Extension.DelayTestTimeout?.toString(),
              textWidthPercent: 0.5,
              onChanged: (String value) {
                setting.Extension.DelayTestTimeout = int.tryParse(value);
              })),
    ];
    List<GroupItemOptions> options4 = [
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.tun,
              onPush: () async {
                showClashSettingsTUN(context);
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.dns,
              onPush: () async {
                showClashSettingsDNS(context);
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.ntp,
              onPush: () async {
                showClashSettingsNTP(context);
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.tls,
              onPush: () async {
                showClashSettingsTLS(context);
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.sniffer,
              onPush: () async {
                showClashSettingsSniffer(context);
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.meta.geo,
              onPush: () async {
                showClashSettingsGEO(context);
              })),
    ];
    if (!appSetting.coreSettingOverwrite) {
      return [
        GroupItem(options: options00),
        GroupItem(options: options0),
      ];
    }
    return [
      GroupItem(options: options00),
      GroupItem(options: options0),
      GroupItem(options: options),
      GroupItem(options: options1),
      GroupItem(options: options2),
      GroupItem(options: options3),
      GroupItem(options: options4),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("coreSettings"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.settingCore,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsTUN(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var setting = ClashSettingManager.getConfig();
    var tun = setting.Tun;
    var extensions = setting.Extension;
    final tunStacks = ClashTunStack.toList();
    List<GroupItemOptions> options = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.enable,
              switchValue: tun.Enable,
              onSwitch: (bool value) async {
                tun.Enable = value;
              })),
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.tun.stack,
              selected:
                  tunStacks.contains(tun.Stack) ? tun.Stack : tunStacks.last,
              strings: tunStacks,
              onPicker: (String? selected) async {
                tun.Stack = selected;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.tun.dnsHijack,
              switchValue: tun.DNSHijack?.isNotEmpty,
              onSwitch: (bool value) async {
                tun.DNSHijack = value ? ["172.19.0.2:53"] : null;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.tun.strictRoute,
              switchValue: tun.StrictRoute,
              onSwitch: (bool value) async {
                tun.StrictRoute = value;
              })),
    ];
    List<GroupItemOptions> options1 = [];
    if (Platform.isAndroid || Platform.isIOS) {
      options1.addAll([
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.tun.appendSystemProxy,
                switchValue: extensions.Tun.HttpProxyEnable,
                onSwitch: (bool value) async {
                  extensions.Tun.HttpProxyEnable = value;
                })),
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.tun.allowBypassSystemProxy,
                switchValue: extensions.Tun.AllowBypass,
                onSwitch: (bool value) async {
                  extensions.Tun.AllowBypass = value;
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.tun.bypassDomain,
                onPush: () async {
                  extensions.Tun.HttpProxyBypassDomain ??= [];
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: ListAddScreen.routSettings("BypassDomain"),
                          builder: (context) => ListAddScreen(
                                title: tcontext.tun.bypassDomain,
                                data: extensions.Tun.HttpProxyBypassDomain!,
                              )));
                }))
      ]);
    }
    if (Platform.isAndroid) {
      //List<String>? IncludePackage;
      //List<String>? ExcludePackage;
    }
    return [
      GroupItem(options: options),
      GroupItem(options: options1),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("tun"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.tun,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsDNS(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var dns = ClashSettingManager.getConfig().DNS;
    final enhancedModes = ClashDnsEnhancedMode.toList();
    final fakeIPFilterModes = ClashFakeIPFilterMode.toList();
    List<GroupItemOptions> options = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.enable,
              switchValue: dns.Enable,
              onSwitch: (bool value) async {
                dns.Enable = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.dns.preferH3,
              switchValue: dns.PreferH3,
              onSwitch: (bool value) async {
                dns.PreferH3 = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.dns.useHosts,
              switchValue: dns.UseHosts,
              onSwitch: (bool value) async {
                dns.UseHosts = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.dns.useSystemHosts,
              switchValue: dns.UseSystemHosts,
              onSwitch: (bool value) async {
                dns.UseSystemHosts = value;
              })),
      /* GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: "RespectRules",
              switchValue: dns.RespectRules,
              onSwitch: (bool value) async {
                dns.RespectRules = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: "DirectNameServerFollowPolicy",
              switchValue: dns.DirectNameServerFollowPolicy,
              onSwitch: (bool value) async {
                dns.DirectNameServerFollowPolicy = value;
              })),*/
    ];
    List<GroupItemOptions> options1 = [
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.dns.enhancedMode,
              selected: enhancedModes.contains(dns.EnhancedMode)
                  ? dns.EnhancedMode
                  : enhancedModes.last,
              strings: enhancedModes,
              onPicker: (String? selected) async {
                dns.EnhancedMode = selected;
              })),
      GroupItemOptions(
          stringPickerOptions: GroupItemStringPickerOptions(
              name: tcontext.dns.fakeIPFilterMode,
              selected: fakeIPFilterModes.contains(dns.FakeIPFilterMode)
                  ? dns.FakeIPFilterMode
                  : fakeIPFilterModes.last,
              strings: fakeIPFilterModes,
              onPicker: (String? selected) async {
                dns.FakeIPFilterMode = selected;
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.dns.fakeIPFilter,
              onPush: () async {
                dns.FakeIPFilter ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: ListAddScreen.routSettings("FakeIPFilter"),
                        builder: (context) => ListAddScreen(
                              title: tcontext.dns.fakeIPFilter,
                              data: dns.FakeIPFilter!,
                            )));
              })),
    ];
    List<GroupItemOptions> options2 = [
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.dns.defaultNameServer,
              onPush: () async {
                dns.DefaultNameserver ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings:
                            ListAddScreen.routSettings("DefaultNameserver"),
                        builder: (context) => ListAddScreen(
                              title: tcontext.dns.defaultNameServer,
                              data: dns.DefaultNameserver!,
                            )));
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.dns.nameServer,
              onPush: () async {
                dns.NameServer ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: ListAddScreen.routSettings("NameServer"),
                        builder: (context) => ListAddScreen(
                              title: tcontext.dns.nameServer,
                              data: dns.NameServer!,
                            )));
              })),

      /*GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: "ProxyServerNameserver",
              onPush: () async {
                dns.ProxyServerNameserver ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings:
                            ListAddScreen.routSettings("ProxyServerNameserver"),
                        builder: (context) => ListAddScreen(
                              title: "ProxyServerNameserver",
                              data: dns.ProxyServerNameserver!,
                            )));
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: "DirectNameServer",
              onPush: () async {
                dns.DirectNameServer ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings:
                            ListAddScreen.routSettings("DirectNameServer"),
                        builder: (context) => ListAddScreen(
                              title: "DirectNameServer",
                              data: dns.DirectNameServer!,
                            )));
              })),*/
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.dns.fallbackNameServer,
              onPush: () async {
                dns.Fallback ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: ListAddScreen.routSettings("Fallback"),
                        builder: (context) => ListAddScreen(
                              title: tcontext.dns.fallbackNameServer,
                              data: dns.Fallback!,
                            )));
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.dns.fallbackGeoIp,
              switchValue: dns.FallbackFilter?.GeoIP,
              onSwitch: (bool value) async {
                dns.FallbackFilter ??= RawFallbackFilter.by();
                dns.FallbackFilter?.GeoIP = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.dns.fallbackGeoIpCode,
              text: dns.FallbackFilter?.GeoIPCode,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                dns.FallbackFilter ??= RawFallbackFilter.by();
                dns.FallbackFilter?.GeoIPCode = value;
              })),
    ];

    return [
      GroupItem(options: options),
      GroupItem(options: options1),
      GroupItem(options: options2),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("dns"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.dns,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsNTP(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var ntp = ClashSettingManager.getConfig().NTP;

    List<GroupItemOptions> options = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.enable,
              switchValue: ntp.Enable,
              onSwitch: (bool value) async {
                ntp.Enable = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.server,
              text: ntp.Server,
              textWidthPercent: 0.5,
              hint: tcontext.meta.required,
              onChanged: (String value) {
                ntp.Server = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.meta.port,
              text: ntp.Port?.toString() ?? "",
              textWidthPercent: 0.5,
              hint: tcontext.meta.required,
              onChanged: (String value) {
                ntp.Port = int.tryParse(value);
              })),
    ];

    return [
      GroupItem(options: options),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("ntp"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.ntp,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsTLS(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var tls = ClashSettingManager.getConfig().TLS;
    List<GroupItemOptions> options = [
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.tls.certificate,
              text: tls.Certificate,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                tls.Certificate = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: tcontext.tls.privateKey,
              text: tls.PrivateKey,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                tls.PrivateKey = value;
              })),
      GroupItemOptions(
          pushOptions: GroupItemPushOptions(
              name: tcontext.tls.customTrustCert,
              onPush: () async {
                tls.CustomTrustCert ??= [];
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: ListAddScreen.routSettings("CustomTrustCert"),
                        builder: (context) => ListAddScreen(
                              title: tcontext.tls.customTrustCert,
                              data: tls.CustomTrustCert!,
                            )));
              })),
    ];

    return [
      GroupItem(options: options),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("tls"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.tls,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsSniffer(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var sniffer = ClashSettingManager.getConfig().Sniffer;
    List<GroupItemOptions> options = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.enable,
              switchValue: sniffer.Enable,
              onSwitch: (bool value) async {
                sniffer.Enable = value;
              })),
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.sniffer.overrideDest,
              switchValue: sniffer.OverrideDest,
              onSwitch: (bool value) async {
                sniffer.OverrideDest = value;
              })),
    ];

    return [
      GroupItem(options: options),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("sniffer"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.sniffer,
                getOptions: getOptions,
              )));
}

Future<void> showClashSettingsGEO(BuildContext context) async {
  final tcontext = Translations.of(context);
  Future<List<GroupItem>> getOptions(BuildContext context) async {
    var setting = ClashSettingManager.getConfig();
    var geo = setting.GeoXUrl;
    List<GroupItemOptions> options = [
      GroupItemOptions(
          switchOptions: GroupItemSwitchOptions(
              name: tcontext.meta.autoUpdate,
              switchValue: setting.GeoAutoUpdate,
              onSwitch: (bool value) async {
                setting.GeoAutoUpdate = value;
              })),
      GroupItemOptions(
          timerIntervalPickerOptions: GroupItemTimerIntervalPickerOptions(
              name: tcontext.meta.updateInterval,
              duration:
                  Duration(seconds: setting.GeoUpdateInterval ?? 7 * 24 * 3600),
              showSeconds: false,
              showMinutes: false,
              onPicker: (bool canceled, Duration? duration) async {
                if (canceled) {
                  return;
                }
                if (duration != null) {
                  return;
                }
                setting.GeoUpdateInterval = duration!.inSeconds;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: "GeoIp",
              text: geo.GeoIp,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                geo.GeoIp = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: "GeoSite",
              text: geo.GeoSite,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                geo.GeoSite = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: "Mmdb",
              text: geo.Mmdb,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                geo.Mmdb = value;
              })),
      GroupItemOptions(
          textFormFieldOptions: GroupItemTextFieldOptions(
              name: "ASN",
              text: geo.ASN,
              textWidthPercent: 0.5,
              onChanged: (String value) {
                geo.ASN = value;
              })),
    ];

    return [
      GroupItem(options: options),
    ];
  }

  await Navigator.push(
      context,
      MaterialPageRoute(
          settings: GroupScreen.routSettings("geo"),
          builder: (context) => GroupScreen(
                title: tcontext.meta.geo,
                getOptions: getOptions,
              )));
}
