// ignore_for_file: empty_catches

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:clashmi/app/utils/convert_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:country/country.dart' as country;

class SettingConfigItemUI {
  String theme = ThemeDefine.kThemeLight;
  bool autoOrientation = false;
  bool disableFontScaler = false;
  bool hideAfterLaunch = false;

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'auto_orientation': autoOrientation,
        'disable_font_scaler': disableFontScaler,
        'hide_after_launch': hideAfterLaunch,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    theme = map["theme"] ?? "";
    autoOrientation = map["auto_orientation"] ?? false;
    disableFontScaler = map["disable_font_scaler"] ?? false;
    hideAfterLaunch = map["hide_after_launch"] ?? false;

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

class SettingConfigItemUIScreen {
  Map<String, dynamic> toJson() => {};
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
  }

  static SettingConfigItemUIScreen fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemUIScreen config = SettingConfigItemUIScreen();
    config.fromJson(map);
    return config;
  }
}

class SettingConfigItemDev {
  static int pprofPortDefault = 3066;
  bool devMode = false;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = {};
    return ret;
  }

  void fromJson(Map<String, dynamic>? map) {}

  static SettingConfigItemDev fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemDev config = SettingConfigItemDev();
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

class SettingConfigItemProxy {
  static const String hostDefault = '127.0.0.1';
  static const String hostDefault2 = 'localhost';
  static const String hostNetwork = '0.0.0.0';

  static int controlPortDefault = 9090;
  String host = hostDefault;
  bool autoSetSystemProxy = getAutoSetSystemProxyDefault();

  Map<String, dynamic> toJson() => {
        'host': host,
        'auto_set_system_proxy': autoSetSystemProxy,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    host = map["host"] ?? hostDefault;

    autoSetSystemProxy =
        map["auto_set_system_proxy"] ?? getAutoSetSystemProxyDefault();
  }

  static SettingConfigItemProxy fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemProxy config = SettingConfigItemProxy();
    config.fromJson(map);
    return config;
  }

  static bool getAutoSetSystemProxyDefault() {
    if (Platform.isWindows) {
      return false;
    }
    return false;
  }
}

class SettingConfigItemPerapp {
  bool enable = true;
  bool isInclude = true; //android
  List<String> _listAndroid = [];
  List<String> _listMacos = [];
  bool hideSystemApp = true;
  bool hideAppIcon = false;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = {
      'enable': enable,
      'is_include': isInclude,
      'list_android': _listAndroid,
      'list_macos': _listMacos,
      'hide_system_app': hideSystemApp,
      'hide_app_icon': hideAppIcon,
    };
    return ret;
  }

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    enable = map["enable"] ?? map["perapp_enable"] ?? true;
    isInclude = map["is_include"] ?? map["perapp_is_include"] ?? true;
    _listAndroid =
        ConvertUtils.getListStringFromDynamic(map["list_android"], true, [])!;
    _listMacos =
        ConvertUtils.getListStringFromDynamic(map["list_macos"], true, [])!;
    if (_listAndroid.isEmpty) {
      _listAndroid = ConvertUtils.getListStringFromDynamic(
          map["list"] ?? map["perapp"], true, [])!;
    }

    hideSystemApp = map["hide_system_app"] ?? true;
    hideAppIcon = map["hide_app_icon"] ?? false;
  }

  static SettingConfigItemPerapp fromJsonStatic(Map<String, dynamic>? map) {
    SettingConfigItemPerapp config = SettingConfigItemPerapp();
    config.fromJson(map);
    return config;
  }

  List<String> get list {
    if (Platform.isAndroid) {
      return _listAndroid;
    } else if (Platform.isMacOS) {
      return _listMacos;
    }
    return [];
  }

  set list(List<String> list) {
    if (Platform.isAndroid) {
      _listAndroid = list;
    } else if (Platform.isMacOS) {
      _listMacos = list;
    }
  }
}

class SettingConfig {
  String languageTag = "";

  SettingConfigItemDev dev = SettingConfigItemDev();
  SettingConfigItemUI ui = SettingConfigItemUI();
  SettingConfigItemUIScreen uiScreen = SettingConfigItemUIScreen();
  SettingConfigItemProxy proxy = SettingConfigItemProxy();
  SettingConfigItemPerapp perapp = SettingConfigItemPerapp();
  SettingConfigItemWebDev webdav = SettingConfigItemWebDev();
  bool alwayOn = false;
  String autoUpdateChannel = "stable"; //stable, beta
  bool coreSettingOverwrite = true;

  Map<String, dynamic> toJson() => {
        'language_tag': languageTag,
        'perapp': perapp,
        'ui': ui,
        'ui_screen': uiScreen,
        'proxy': proxy,
        'webdav': webdav,
        'alway_on': alwayOn,
        'auto_update_channel': autoUpdateChannel,
        'core_setting_overwrite': coreSettingOverwrite,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    languageTag = map["language_tag"] ?? "";
    perapp = SettingConfigItemPerapp.fromJsonStatic(map["perapp"]);
    ui = SettingConfigItemUI.fromJsonStatic(map["ui"]);
    uiScreen =
        SettingConfigItemUIScreen.fromJsonStatic(map["ui_screen"] ?? map);
    proxy = SettingConfigItemProxy.fromJsonStatic(map["proxy"]);
    alwayOn = map["alway_on"] ?? false;
    autoUpdateChannel = map["auto_update_channel"] ?? "stable";
    if (autoUpdateChannel.isEmpty) {
      autoUpdateChannel = "stable";
    }
    coreSettingOverwrite = map["core_setting_overwrite"] ?? true;
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
