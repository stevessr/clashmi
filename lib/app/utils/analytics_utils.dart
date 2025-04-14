import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clashmi/app/modules/remote_config_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/app/utils/app_utils.dart';
import 'package:clashmi/app/utils/did.dart';
import 'package:clashmi/app/utils/http_utils.dart';
import 'package:clashmi/app/utils/install_referrer_utils.dart';
import 'package:clashmi/app/utils/clashmi_url_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:libclash_vpn_service/vpn_service.dart';

enum AnalyticsLevel { debug, info, warning, error, fatal }

const int analyticsEventTypeUA = 1 << 0;
const int analyticsEventTypeApp = 1 << 1;
const int analyticsEventTypeErr = 1 << 2;
const int analyticsEventTypeException = 1 << 3;
const int analyticsEventTypeActive = 1 << 4;

const int analyticsEventTypeOnlyActive = analyticsEventTypeActive;

const int analyticsEventTypeNoUA = analyticsEventTypeApp |
    analyticsEventTypeErr |
    analyticsEventTypeException |
    analyticsEventTypeActive;

const int analyticsEventTypeAll = analyticsEventTypeUA |
    analyticsEventTypeApp |
    analyticsEventTypeErr |
    analyticsEventTypeException |
    analyticsEventTypeActive;

class AnalyticsCacheItem {
  int type = 0;
  String name = "";
  Map<String, Object?>? params;
  DateTime ts = DateTime.now();
  bool repeatable = false;
}

abstract final class AnalyticsUtils {
  static int _analyticsEventType = analyticsEventTypeAll;

  static Timer? _timer;
  static String? _installRefer;
  static bool? _inProduction;
  static String? _did;
  static bool? _firstTime;
  static PackageInfo? _packageInfo;
  static String? _version;
  static String? _abis;
  static DateTime? _cacheTime;
  static List<AnalyticsCacheItem> _cacheList = [];
  static final DateTime _startTime = DateTime.now();
  static String? _operatingSystem;
  static String? _operatingSystemVersion;

  static void setEventType(int type) {
    _analyticsEventType = type;
  }

  static String getStartTime() {
    Duration dur = DateTime.now().difference(_startTime);
    return dur.toString().split(".")[0].replaceAll("-", "");
  }

  static Future<void> logEvent(
      {required int analyticsEventType,
      required String name,
      Map<String, Object?>? parameters,
      bool forceSubmit = false,
      bool repeatable = false}) async {
    try {
      if ((_analyticsEventType & analyticsEventType) == 0) {
        return;
      }

      _inProduction ??= const bool.fromEnvironment("dart.vm.product");
      if (_inProduction != true) {
        return;
      }
      _operatingSystem ??= Platform.operatingSystem;
      _operatingSystemVersion ??= Platform.operatingSystemVersion;

      if (analyticsEventType != analyticsEventTypeActive) {
        bool reject = rejectSubmit();
        if (reject) {
          return;
        }
      }

      _timer ??= Timer.periodic(const Duration(seconds: 60), (timer) async {
        await trySubmit(false);
      });

      if (_cacheList.length < 100) {
        AnalyticsCacheItem item = AnalyticsCacheItem();
        item.type = analyticsEventType;

        item.name = name;
        item.params = parameters;
        item.ts = DateTime.now();
        item.repeatable = repeatable;
        _cacheList.add(item);
      }
      await trySubmit(forceSubmit);
    } catch (err) {
      Log.w("AnalyticsUtils.logEvent exception ${err.toString()} ");
    }
  }

  static Future<void> trySubmit(bool forceSubmit) async {
    var now = DateTime.now();
    if (!forceSubmit) {
      if (_cacheTime == null || _cacheList.isEmpty) {
        _cacheTime = now;
        return;
      }

      var dif = now.difference(_cacheTime!);
      if (dif.inSeconds < 60) {
        return;
      }
      _cacheTime = now;
    }

    Map<String, Object?> cp = await getParameters();
    List<String> keys = [];
    int tsStart = 0;
    Set<int> noRepeat = {};
    for (var i in _cacheList) {
      if (tsStart == 0) {
        tsStart = i.ts.millisecondsSinceEpoch;
      }
      Map<String, Object?> allParameters = {};
      allParameters["type"] = getEventTypeString(i.type);
      allParameters["name"] = i.name;
      allParameters["params"] = i.params;
      if (!i.repeatable) {
        String content = jsonEncode(allParameters);
        int hashcode = content.hashCode;
        if (noRepeat.contains(hashcode)) {
          continue;
        }
        noRepeat.add(hashcode);
      }
      allParameters["ts_s"] = tsStart;
      allParameters["ts_i"] = keys.length + 1;
      allParameters["ts"] = i.ts.millisecondsSinceEpoch;
      try {
        keys.add(jsonEncode(allParameters));
      } catch (err) {
        Log.w("AnalyticsUtils.trySubmit encode exception ${err.toString()} ");
      }
    }
    _cacheList = [];
    String outpost = RemoteConfigManager.getConfig().outpost;
    String queryParams1 =
        ClashMiUrlUtils.getQueryParamsForAnalytics(keys.length);

    var body = {"common": cp, "event": keys};
    String content = jsonEncode(body);

    var uri = Uri.parse("$outpost?$queryParams1");
    await submit(uri, null, content);
  }

  static Future<bool> submit(Uri uri, int? proxyPort, String content) async {
    var client = HttpClient();
    try {
      client.idleTimeout = const Duration(seconds: 5);
      client.userAgent = await HttpUtils.getUserAgent();
      if (proxyPort != null) {
        client.findProxy = (Uri uri) => "PROXY 127.0.0.1:$proxyPort";
      }
      HttpClientRequest request = await client.postUrl(uri);

      request.headers.set(HttpHeaders.connectionHeader, "close");
      request.headers.set(HttpHeaders.acceptHeader, "*/*");
      request.headers.set(
          HttpHeaders.contentTypeHeader, "application/json; charset=UTF-8");

      var bytes = request.encoding.encode(content);
      request.headers
          .set(HttpHeaders.contentLengthHeader, bytes.length.toString());
      request.add(bytes);

      await request.close();
    } catch (err) {
      return false;
    } finally {
      client.close(force: true);
    }
    return true;
  }

  static Future<Map<String, Object?>> getParameters() async {
    var config = SettingManager.getConfig();

    _installRefer ??= await InstallReferrerUtils.getString();
    _did ??= await Did.getDid();
    _firstTime ??= await Did.getFirstTime();
    _packageInfo ??= await PackageInfo.fromPlatform();
    _version ??= AppUtils.getBuildinVersion();
    _abis ??= await FlutterVpnService.getABIs();

    String planguageTag = [
      ui.PlatformDispatcher.instance.locale.languageCode,
      ui.PlatformDispatcher.instance.locale.countryCode ?? ""
    ].join("-");
    Map<String, Object?> parameters = {};

    parameters["s_r_c"] =
        ui.PlatformDispatcher.instance.locale.countryCode ?? "";
    parameters["l_t"] = config.languageTag;
    parameters["s_l_t"] = planguageTag;
    parameters["t_z_o"] = DateTime.now().timeZoneOffset.inHours;
    parameters["p"] = _operatingSystem;
    parameters["p_v"] = _operatingSystemVersion;
    parameters["v"] = _version;
    parameters["abis"] = _abis;
    parameters["i_r"] = _installRefer!;
    parameters["i_s"] = _packageInfo!.installerStore;
    parameters["did"] = _did!;
    parameters["new"] = _firstTime!;
    parameters["t_f_l"] = getStartTime();

    parameters["a_u_c"] = config.autoUpdateChannel;

    return parameters;
  }

  static String getEventTypeString(int type) {
    if (type == analyticsEventTypeUA) {
      return "ua";
    }
    if (type == analyticsEventTypeApp) {
      return "app";
    }
    if (type == analyticsEventTypeErr) {
      return "err";
    }
    if (type == analyticsEventTypeException) {
      return "exception";
    }
    if (type == analyticsEventTypeActive) {
      return "active";
    }

    return type.toString();
  }

  static bool rejectSubmit() {
    return false;
  }
}
