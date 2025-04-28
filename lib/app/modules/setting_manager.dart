// ignore_for_file: empty_catches

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/widgets/text_field.dart';
import 'package:country/country.dart' as country;

class SettingConfigItemUI {
  String theme = ThemeDefine.kThemeLight;
  bool autoOrientation = false;
  bool disableFontScaler = false;
  bool hideAfterLaunch = false;
  bool tvMode = false;
  bool perAppHideSystemApp = true;
  bool perAppHideAppIcon = false;
  Map<String, dynamic> toJson() => {
        'theme': theme,
        'auto_orientation': autoOrientation,
        'disable_font_scaler': disableFontScaler,
        'hide_after_launch': hideAfterLaunch,
        'tv_mode': tvMode,
        'perapp_hide_system_app': perAppHideSystemApp,
        'perapp_hide_app_icon': perAppHideAppIcon,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    theme = map["theme"] ?? "";
    autoOrientation = map["auto_orientation"] ?? false;
    disableFontScaler = map["disable_font_scaler"] ?? false;
    hideAfterLaunch = map["hide_after_launch"] ?? false;
    perAppHideSystemApp = map["perapp_hide_system_app"] ?? true;
    perAppHideAppIcon = map["perapp_hide_app_icon"] ?? false;
    if (Platform.isAndroid) {
      tvMode = map["tv_mode"] ?? false;
      TextFieldEx.popupEdit = tvMode;
    }

    switch (theme) {
      case "dark":
        theme = ThemeDefine.kThemeDark;
        break;

      case "light":
        theme = ThemeDefine.kThemeLight;
        break;

      case "system":
        theme = ThemeDefine.kThemeSystem;
        break;

      default:
        theme = ThemeDefine.kThemeLight;
        break;
    }
  }

  static SettingConfigItemUI fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemUI config = SettingConfigItemUI();
    config.fromJson(map);
    return config;
  }
}

class SettingConfigItemWebDev {
  String url = "";
  String user = "";
  String password = "";

  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = {
      'url': url,
      'user': user,
      'password': password,
    };
    return ret;
  }

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    url = map["url"] ?? "";
    user = map["user"] ?? "";
    password = map["password"] ?? "";
  }

  static SettingConfigItemWebDev fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemWebDev config = SettingConfigItemWebDev();
    config.fromJson(map);
    return config;
  }
}

class SettingConfig {
  static const int kDefaultBoardPort = 7066;
  String languageTag = "";
  SettingConfigItemUI ui = SettingConfigItemUI();

  SettingConfigItemWebDev webdav = SettingConfigItemWebDev();
  bool alwayOn = false;
  String autoUpdateChannel = "stable"; //stable, beta
  bool autoSetSystemProxy = getAutoSetSystemProxyDefault();
  String _userAgent = "";
  int boardPort = kDefaultBoardPort;

  Map<String, dynamic> toJson() => {
        'language_tag': languageTag,
        'ui': ui,
        'webdav': webdav,
        'alway_on': alwayOn,
        'auto_update_channel': autoUpdateChannel,
        'auto_set_system_proxy': autoSetSystemProxy,
        'user_agent': _userAgent,
        'board_port': boardPort,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    languageTag = map["language_tag"] ?? "";

    ui = SettingConfigItemUI.fromJsonStatic(map["ui"]);

    alwayOn = map["alway_on"] ?? false;
    autoUpdateChannel = map["auto_update_channel"] ?? "stable";
    if (autoUpdateChannel.isEmpty) {
      autoUpdateChannel = "stable";
    }
    autoSetSystemProxy =
        map["auto_set_system_proxy"] ?? getAutoSetSystemProxyDefault();
    _userAgent = map["user_agent"] ?? "";
    boardPort = map["board_port"] ?? kDefaultBoardPort;
  }

  String userAgent() {
    if (_userAgent.isEmpty) {
      return "ClashMeta/1.19.5";
    }
    return _userAgent;
  }

  void setUserAgent(String ua) {
    _userAgent = ua;
  }

  static SettingConfig fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfig config = SettingConfig();
    config.fromJson(map);
    return config;
  }

  void clear() {}

  country.Country? currentCountry() {
    final data = country.Countries.values.where((country) {
      return false;
    }).toList();
    if (data.isEmpty) {
      return null;
    }
    return data[0];
  }

  static String languageTagForCountry() {
    return LocaleSettings.currentLocale.languageTag.replaceAll("-", "_");
  }

  static bool getAutoSetSystemProxyDefault() {
    if (Platform.isWindows) {
      return false;
    }
    return false;
  }
}

class SettingManager {
  static bool _savingConfig = false;
  static final SettingConfig _config = SettingConfig();
  static Future<void> init({bool fromBackupRestore = false}) async {
    await loadConfig();
    bool save = await parseConfig();
    if (save) {
      saveConfig();
    }
  }

  static Future<void> uninit() async {}
  static Future<void> reload() async {
    await loadConfig();
  }

  static Future<bool> parseConfig() async {
    bool save = false;

    String languageTag = "en";
    if (_config.languageTag.isNotEmpty) {
      for (var locale in AppLocale.values) {
        if (locale.languageTag == _config.languageTag) {
          languageTag = locale.languageTag;
          break;
        }
      }
    } else {
      String planguageTag = [
        PlatformDispatcher.instance.locale.languageCode,
        PlatformDispatcher.instance.locale.countryCode ?? ""
      ].join("-");
      for (var locale in AppLocale.values) {
        if (locale.languageTag == planguageTag) {
          languageTag = locale.languageTag;
          break;
        }
      }
    }

    if (languageTag.isEmpty) {
      languageTag = "en";
    }

    for (var locale in AppLocale.values) {
      if (languageTag == locale.languageTag) {
        save = true;
        _config.languageTag = languageTag;
        var current = LocaleSettings.currentLocale;
        if (current != locale) {
          await LocaleSettings.setLocale(locale);
        }

        break;
      }
    }

    return save;
  }

  static Future<void> loadConfig() async {
    String filePath = await PathUtils.settingFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (!exists) {
      return;
    }
    String content = "";
    try {
      content = await file.readAsString();
      if (content.isNotEmpty) {
        var config = jsonDecode(content);
        _config.fromJson(config);
      }
    } catch (err, stacktrace) {
      Log.w("SettingManager.loadConfig exception $filePath ${err.toString()}");
    }
  }

  static void saveConfig() async {
    if (_savingConfig) {
      return;
    }
    _savingConfig = true;
    String filePath = await PathUtils.settingFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(_config.toJson());
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {
      Log.w("SettingManager.saveConfig exception  $filePath ${err.toString()}");
    }
    _savingConfig = false;
  }

  static SettingConfig getConfig() {
    return _config;
  }
}
