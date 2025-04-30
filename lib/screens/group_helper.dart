// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:io';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/modules/profile_patch_manager.dart';
import 'package:clashmi/screens/add_profile_patch_by_import_from_file_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/modules/auto_update_manager.dart';
import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/remote_config_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/backup_and_sync_utils.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/app/utils/platform_utils.dart';
import 'package:clashmi/app/utils/url_launcher_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/backup_and_sync_icloud_screen.dart';
import 'package:clashmi/screens/backup_and_sync_webdav_screen.dart';
import 'package:clashmi/screens/backup_helper.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:clashmi/screens/file_view_screen.dart';
import 'package:clashmi/screens/group_item_creator.dart';
import 'package:clashmi/screens/group_item_options.dart';
import 'package:clashmi/screens/group_screen.dart';
import 'package:clashmi/screens/language_settings_screen.dart';
import 'package:clashmi/screens/list_add_screen.dart';
import 'package:clashmi/screens/perapp_android_screen.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/themes.dart';
import 'package:clashmi/screens/version_update_screen.dart';
import 'package:clashmi/screens/webview_helper.dart';
import 'package:clashmi/screens/widgets/text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class GroupHelper {
  static Future<void> newVersionUpdate(BuildContext context) async {
    AutoUpdateCheckVersion versionCheck = AutoUpdateManager.getVersionCheck();
    if (!versionCheck.newVersion) {
      return;
    }

    if (AutoUpdateManager.isSupport()) {
      String? installerNew = await AutoUpdateManager.checkReplace();
      if (!context.mounted) {
        return;
      }
      if (installerNew != null) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                settings: VersionUpdateScreen.routSettings(),
                fullscreenDialog: true,
                builder: (context) => const VersionUpdateScreen(force: false)));
      } else {
        if (Platform.isAndroid) {
          await UrlLauncherUtils.loadUrl(versionCheck.url,
              mode: LaunchMode.externalApplication);
        } else {
          await WebviewHelper.loadUrl(
              context, versionCheck.url, "newVersionUpdate");
        }
      }
    } else {
      await WebviewHelper.loadUrl(
          context, versionCheck.url, "newVersionUpdate");
    }
  }

  static Future<void> showBackupAndSync(BuildContext context) async {
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      final tcontext = Translations.of(context);

      List<GroupItemOptions> options = [
        Platform.isIOS || Platform.isMacOS
            ? GroupItemOptions(
                pushOptions: GroupItemPushOptions(
                    name: tcontext.meta.iCloud,
                    onPush: () async {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              settings:
                                  BackupAndSyncIcloudScreen.routSettings(),
                              builder: (context) =>
                                  const BackupAndSyncIcloudScreen()));
                    }))
            : GroupItemOptions(),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.webdav,
                onPush: () async {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: BackupAndSyncWebdavScreen.routSettings(),
                          builder: (context) =>
                              const BackupAndSyncWebdavScreen()));
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.importAndExport,
                onPush: () async {
                  onTapImportExport(context);
                }))
      ];

      return [
        GroupItem(options: options),
      ];
    }

    final tcontext = Translations.of(context);
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: GroupScreen.routSettings("help"),
            builder: (context) => GroupScreen(
                  title: tcontext.meta.help,
                  getOptions: getOptions,
                )));
    SettingManager.saveConfig();
  }

  static Future<void> onTapImportExport(BuildContext context) async {
    final tcontext = Translations.of(context);

    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      List<GroupItemOptions> options = [
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.import,
                onPush: () async {
                  onTapImport(context);
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.export,
                onPush: () async {
                  onTapExport(context);
                })),
      ];
      return [GroupItem(options: options)];
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: GroupScreen.routSettings("importAndExport"),
            builder: (context) => GroupScreen(
                  title: tcontext.meta.importAndExport,
                  getOptions: getOptions,
                )));
  }

  static Future<void> onTapImport(BuildContext context) async {
    final tcontext = Translations.of(context);
    List<String> extensions = [BackupAndSyncUtils.getZipExtension()];
    try {
      FilePickerResult? pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (!context.mounted) {
        return;
      }
      if (pickResult != null) {
        String filePath = pickResult.files.first.path!;
        String ext = path.extension(filePath).replaceAll('.', '').toLowerCase();
        if (!extensions.contains(ext)) {
          DialogUtils.showAlertDialog(
              context, tcontext.meta.fileTypeInvalid(p: ext));
          return;
        }
        if (!context.mounted) {
          return;
        }
        await BackupHelper.backupRestoreFromZip(context, filePath);
      }
    } catch (err, stacktrace) {
      if (!context.mounted) {
        return;
      }
      DialogUtils.showAlertDialog(context, err.toString(),
          showCopy: true, showFAQ: true, withVersion: true);
    }
  }

  static Future<void> onTapExport(BuildContext context) async {
    try {
      String? filePath;
      if (PlatformUtils.isMobile()) {
        String dir = await PathUtils.cacheDir();
        filePath = path.join(dir, BackupAndSyncUtils.getZipFileName());
      } else {
        filePath = await FilePicker.platform.saveFile(
          fileName: BackupAndSyncUtils.getZipFileName(),
          lockParentWindow: true,
        );
      }

      if (filePath != null) {
        if (!context.mounted) {
          return;
        }
        ReturnResultError? error =
            await BackupHelper.backupToZip(context, filePath);
        if (!context.mounted) {
          FileUtils.deletePath(filePath);
          return;
        }
        if (error != null) {
          DialogUtils.showAlertDialog(context, error.message,
              showCopy: true, showFAQ: true, withVersion: true);
          return;
        }
        if (PlatformUtils.isMobile()) {
          try {
            await Share.shareXFiles([XFile(filePath)]);
          } catch (err) {
            if (!context.mounted) {
              return;
            }
            DialogUtils.showAlertDialog(context, err.toString(),
                showCopy: true, showFAQ: true, withVersion: true);
          }
        }
      }
    } catch (err, stacktrace) {
      if (!context.mounted) {
        return;
      }
      DialogUtils.showAlertDialog(context, err.toString(),
          showCopy: true, showFAQ: true, withVersion: true);
    }
  }

  static Future<void> showHelp(BuildContext context) async {
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      final tcontext = Translations.of(context);

      List<GroupItemOptions> options = [
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.download,
                onPush: () async {
                  var remoteConfig = RemoteConfigManager.getConfig();
                  await WebviewHelper.loadUrl(
                      context, remoteConfig.download, tcontext.meta.download);
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.tutorial,
                onPush: () async {
                  var remoteConfig = RemoteConfigManager.getConfig();
                  await WebviewHelper.loadUrl(
                      context, remoteConfig.tutorial, tcontext.meta.tutorial);
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.faq,
                onPush: () async {
                  var remoteConfig = RemoteConfigManager.getConfig();
                  await WebviewHelper.loadUrl(
                      context, remoteConfig.faq, tcontext.meta.faq);
                })),
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: "Telegram",
                onPush: () async {
                  var remoteConfig = RemoteConfigManager.getConfig();
                  await WebviewHelper.loadUrl(
                      context, remoteConfig.telegram, "Telegram");
                })),
      ];

      return [
        GroupItem(options: options),
      ];
    }

    final tcontext = Translations.of(context);
    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: GroupScreen.routSettings("help"),
            builder: (context) => GroupScreen(
                  title: tcontext.meta.help,
                  getOptions: getOptions,
                )));
    SettingManager.saveConfig();
  }

  static Future<void> showAppSettings(BuildContext context) async {
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
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
                  Provider.of<Themes>(context, listen: false)
                      .setTheme(selected, true);
                })),
        Platform.isAndroid
            ? GroupItemOptions(
                switchOptions: GroupItemSwitchOptions(
                    name: tcontext.meta.tvMode,
                    switchValue: setting.ui.tvMode,
                    onSwitch: (bool value) async {
                      setting.ui.tvMode = value;
                      TextFieldEx.popupEdit = setting.ui.tvMode;
                    }))
            : GroupItemOptions(),
        GroupItemOptions(
            textFormFieldOptions: GroupItemTextFieldOptions(
                name: tcontext.meta.userAgent,
                text: setting.userAgent(),
                textWidthPercent: 0.5,
                onChanged: (String value) {
                  setting.setUserAgent(value);
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
        GroupItemOptions(
            textFormFieldOptions: GroupItemTextFieldOptions(
                name: tcontext.meta.boardPort,
                text: setting.boardPort.toString(),
                textWidthPercent: 0.5,
                onChanged: (String value) {
                  setting.boardPort =
                      int.tryParse(value) ?? SettingConfig.kDefaultBoardPort;
                })),
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
    SettingManager.saveConfig();
  }

  static Future<void> showClashSettings(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      const inProduction = bool.fromEnvironment("dart.vm.product");
      final currentPatch = ProfilePatchManager.getCurrent();
      final remark = currentPatch.remark.isEmpty
          ? currentPatch.getShowName(context)
          : currentPatch.remark;
      final started = await VPNService.getStarted();
      if (!context.mounted) {}
      var setting = ClashSettingManager.getConfig();

      var dns = setting.DNS!;
      var extensions = setting.Extension!;
      final logLevels = ClashLogLevel.toList();
      final globalFingerprints = ClashGlobalClientFingerprint.toList();
      List<GroupItemOptions> options = [
        GroupItemOptions(
            textOptions: GroupItemTextOptions(
          name: "",
          text: tcontext.meta.coreSettingTips,
          textColor: Colors.green,
          textWidthPercent: 1,
        )),
      ];
      List<GroupItemOptions> options1 = [
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.reset,
                onPush: () async {
                  ClashSettingManager.reset();
                  ProfilePatchManager.reset();
                })),
      ];
      List<GroupItemOptions> options2 = [
        GroupItemOptions(
            pushOptions: GroupItemPushOptions(
                name: tcontext.meta.overwrite,
                text: remark,
                textWidthPercent: 0.5,
                onPush: () async {
                  await showProfilePatch(context);
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
        Platform.isAndroid
            ? GroupItemOptions(
                pushOptions: GroupItemPushOptions(
                    name: tcontext.PerAppAndroidScreen.title,
                    onPush: () async {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              settings: PerAppAndroidScreen.routSettings(),
                              builder: (context) =>
                                  const PerAppAndroidScreen()));
                    }))
            : GroupItemOptions(),
        !inProduction
            ? GroupItemOptions(
                textFormFieldOptions: GroupItemTextFieldOptions(
                    name: "Pprof Address",
                    text: extensions.PprofAddr,
                    textWidthPercent: 0.5,
                    onChanged: (String value) {
                      extensions.PprofAddr = value;
                    }))
            : GroupItemOptions(),
        !inProduction
            ? GroupItemOptions(
                pushOptions: GroupItemPushOptions(
                    name: "Pprof",
                    onPush: () async {
                      if (extensions.PprofAddr == null ||
                          extensions.PprofAddr!.isEmpty) {
                        return;
                      }
                      await WebviewHelper.loadUrl(
                          context,
                          "http://${extensions.PprofAddr}/debug/pprof/",
                          "pprof",
                          title: "Pprof");
                    }))
            : GroupItemOptions(),
      ];

      List<GroupItemOptions> options3 = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: "IPv6",
                switchValue: setting.IPv6,
                onSwitch: (bool value) async {
                  setting.IPv6 = value;
                  dns.IPv6 = value;
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
      List<GroupItemOptions> options4 = [
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
      List<GroupItemOptions> options5 = [
        GroupItemOptions(
            timerIntervalPickerOptions: GroupItemTimerIntervalPickerOptions(
                name: tcontext.meta.tcpkeepAliveInterval,
                duration: setting.DisableKeepAlive == true
                    ? null
                    : Duration(seconds: setting.KeepAliveInterval ?? 30),
                showDays: false,
                showHours: false,
                showSeconds: true,
                showMinutes: true,
                showDisable: true,
                onPicker: (bool canceled, Duration? duration) async {
                  if (canceled) {
                    return;
                  }
                  setting.DisableKeepAlive = duration == null;
                  setting.KeepAliveIdle = duration?.inSeconds;
                  setting.KeepAliveInterval = duration?.inSeconds;
                })),
      ];
      List<GroupItemOptions> options6 = [
        GroupItemOptions(
            textFormFieldOptions: GroupItemTextFieldOptions(
                name: tcontext.meta.delayTestUrl,
                text: extensions.DelayTestUrl,
                textWidthPercent: 0.5,
                onChanged: (String value) {
                  extensions.DelayTestUrl = value;
                })),
        GroupItemOptions(
            textFormFieldOptions: GroupItemTextFieldOptions(
                name: tcontext.meta.delayTestTimeout,
                text: extensions.DelayTestTimeout?.toString(),
                textWidthPercent: 0.5,
                onChanged: (String value) {
                  extensions.DelayTestTimeout = int.tryParse(value);
                })),
      ];
      List<GroupItemOptions> options7 = [
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
      List<GroupItem> groups = [];
      if (started) {
        groups.add(GroupItem(options: options));
      }

      if (currentPatch.id.isEmpty ||
          currentPatch.id == kProfilePatchBuildinOverwrite) {
        groups.addAll([
          GroupItem(options: options1),
          GroupItem(options: options2),
          GroupItem(options: options3),
          GroupItem(options: options4),
          GroupItem(options: options5),
          GroupItem(options: options6),
          GroupItem(options: options7),
        ]);
      } else {
        groups.addAll([
          GroupItem(options: options1),
          GroupItem(options: options2),
        ]);
      }

      return groups;
    }

    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: GroupScreen.routSettings("coreSettings"),
            builder: (context) => GroupScreen(
                  title: tcontext.meta.settingCore,
                  getOptions: getOptions,
                  onDone: (context) async {
                    final currentPatch = ProfilePatchManager.getCurrent();
                    final content = await ClashSettingManager.getPatchContent(
                        currentPatch.id.isEmpty ||
                            currentPatch.id == kProfilePatchBuildinOverwrite);

                    if (!context.mounted) {
                      return false;
                    }
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            settings: FileViewScreen.routSettings(),
                            builder: (context) => FileViewScreen(
                                  title:
                                      PathUtils.serviceCorePatchFinalFileName(),
                                  content: content,
                                )));

                    return false;
                  },
                  onDoneIcon: Icons.file_present,
                )));
    ClashSettingManager.saveSetting();
    ProfilePatchManager.save();
    ProfileManager.save();
  }

  static Future<void> showProfilePatch(BuildContext context) async {
    final tcontext = Translations.of(context);
    final currentPatch = ProfilePatchManager.getCurrent();
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      List<GroupItemOptions> options = [
        GroupItemOptions(
            textOptions: GroupItemTextOptions(
                name: "",
                text: tcontext.profilePatchMode.overwrite,
                textStyle: TextStyle(
                    color: currentPatch.id == kProfilePatchBuildinOverwrite
                        ? ThemeDefine.kColorBlue
                        : null),
                onPush: () async {
                  ProfilePatchManager.setCurrent(kProfilePatchBuildinOverwrite);
                  Navigator.of(context).pop();
                })),
        GroupItemOptions(
            textOptions: GroupItemTextOptions(
                name: "",
                text: tcontext.profilePatchMode.noOverwrite,
                textStyle: TextStyle(
                    color: currentPatch.id == kProfilePatchBuildinNoOverwrite
                        ? ThemeDefine.kColorBlue
                        : null),
                onPush: () async {
                  ProfilePatchManager.setCurrent(
                      kProfilePatchBuildinNoOverwrite);
                  Navigator.of(context).pop();
                }))
      ];
      List<GroupItemOptions> options1 = [];
      final profilePatchs = ProfilePatchManager.getProfilePatchs();
      for (var patch in profilePatchs) {
        options1.add(GroupItemOptions(
            textOptions: GroupItemTextOptions(
                name: "",
                text: patch.remark,
                textWidthPercent: 0.8,
                textStyle: TextStyle(
                    color: currentPatch.id == patch.id
                        ? ThemeDefine.kColorBlue
                        : null),
                child: InkWell(
                  onTap: () {
                    ProfilePatchManager.removeProfilePatch(patch.id);
                    ProfileManager.removePatch(patch.id);
                    setstate?.call();
                  },
                  child: Icon(
                    Icons.remove_circle_outlined,
                    color: Colors.red,
                  ),
                ),
                onPush: () async {
                  ProfilePatchManager.setCurrent(patch.id);
                  Navigator.of(context).pop();
                })));
      }
      if (options1.isNotEmpty) {
        return [
          GroupItem(options: options),
          GroupItem(options: options1),
        ];
      }
      return [
        GroupItem(options: options),
      ];
    }

    await Navigator.push(
        context,
        MaterialPageRoute(
            settings: GroupScreen.routSettings("overwrite"),
            builder: (context) => GroupScreen(
                title: tcontext.meta.overwrite,
                getOptions: getOptions,
                onDoneIcon: Icons.add,
                onDone: (BuildContext context) async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: AddProfilePatchByImportFromFileScreen
                              .routSettings(),
                          builder: (context) =>
                              const AddProfilePatchByImportFromFileScreen()));
                  return false;
                })));
  }

  static Future<void> showClashSettingsTUN(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var tun = setting.Tun!;
      var extensions = setting.Extension!;
      final tunStacks = ClashTunStack.toList();
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: tun.OverWrite,
                onSwitch: (bool value) async {
                  tun.OverWrite = value;
                })),
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
      if (Platform.isAndroid) {
        options1.addAll([
          GroupItemOptions(
              switchOptions: GroupItemSwitchOptions(
                  name: tcontext.tun.allowBypass,
                  switchValue: extensions.Tun.httpProxy.AllowBypass,
                  onSwitch: (bool value) async {
                    extensions.Tun.httpProxy.AllowBypass = value;
                  })),
        ]);
      }
      if (Platform.isAndroid || Platform.isIOS) {
        options1.addAll([
          GroupItemOptions(
              switchOptions: GroupItemSwitchOptions(
                  name: tcontext.tun.appendHttpProxy,
                  switchValue: extensions.Tun.httpProxy.Enable,
                  onSwitch: (bool value) async {
                    extensions.Tun.httpProxy.Enable = value;
                    extensions.Tun.httpProxy.Server =
                        value ? "127.0.0.1" : null;
                    extensions.Tun.httpProxy.ServerPort =
                        value ? setting.MixedPort : null;
                  })),
          GroupItemOptions(
              pushOptions: GroupItemPushOptions(
                  name: tcontext.tun.bypassHttpProxyDomain,
                  onPush: () async {
                    extensions.Tun.httpProxy.BypassDomain ??= [];
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            settings: ListAddScreen.routSettings(
                                "HttpProxyBypassDomain"),
                            builder: (context) => ListAddScreen(
                                  title: tcontext.tun.bypassHttpProxyDomain,
                                  data: extensions.Tun.httpProxy.BypassDomain!,
                                )));
                  }))
        ]);
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

  static Future<void> showClashSettingsDNS(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var dns = setting.DNS!;
      final enhancedModes = ClashDnsEnhancedMode.toList();
      final fakeIPFilterModes = ClashFakeIPFilterMode.toList();
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: dns.OverWrite,
                onSwitch: (bool value) async {
                  dns.OverWrite = value;
                })),
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

  static Future<void> showClashSettingsNTP(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var ntp = setting.NTP!;
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: ntp.OverWrite,
                onSwitch: (bool value) async {
                  ntp.OverWrite = value;
                })),
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

  static Future<void> showClashSettingsTLS(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var tls = setting.TLS!;
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: tls.OverWrite,
                onSwitch: (bool value) async {
                  tls.OverWrite = value;
                })),
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
                          settings:
                              ListAddScreen.routSettings("CustomTrustCert"),
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

  static Future<void> showClashSettingsSniffer(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var sniffer = setting.Sniffer!;
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: sniffer.OverWrite,
                onSwitch: (bool value) async {
                  sniffer.OverWrite = value;
                })),
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

  static Future<void> showClashSettingsGEO(BuildContext context) async {
    final tcontext = Translations.of(context);
    Future<List<GroupItem>> getOptions(
        BuildContext context, SetStateCallback? setstate) async {
      var setting = ClashSettingManager.getConfig();
      var geo = setting.GeoXUrl!;
      List<GroupItemOptions> options = [
        GroupItemOptions(
            switchOptions: GroupItemSwitchOptions(
                name: tcontext.meta.overwrite,
                switchValue: geo.OverWrite,
                onSwitch: (bool value) async {
                  geo.OverWrite = value;
                })),
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
                duration: Duration(
                    seconds: setting.GeoUpdateInterval ?? 7 * 24 * 3600),
                showMinutes: false,
                showSeconds: false,
                showDisable: false,
                onPicker: (bool canceled, Duration? duration) async {
                  if (canceled) {
                    return;
                  }
                  if (duration == null) {
                    return;
                  }
                  setting.GeoUpdateInterval = duration.inSeconds;
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
}
