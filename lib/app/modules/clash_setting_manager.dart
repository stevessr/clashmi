// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/clash/clash_http_api.dart';
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/app_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class ClashSettingManager {
  static const _gateWay = "172.19.0";
  static const _gateWay6 = "fdfe:dcbe:9876::1";
  static RawConfig _setting = defaultConfig();

  static Future<void> init() async {
    ClashHttpApi.getControlPort = () {
      return getControlPort();
    };
    await loadSetting();
    await initGeo();
  }

  static Future<void> reload() async {
    await loadSetting();
  }

  static RawTun defaultTun() {
    return RawTun.by(
        OverWrite: true,
        Enable:
            true, //Platform.isAndroid || Platform.isIOS || Platform.isMacOS,
        Stack: "gvisor",
        MTU: 9000,
        Inet4Address: ["$_gateWay.1/30"],
        Inet6Address: ["$_gateWay6/126"],
        DNSHijack: ["$_gateWay.2:53"]);
  }

  static RawDNS defaultDNS() {
    return RawDNS.by(
      OverWrite: true,
      Enable: true,
      PreferH3: true,
      IPv6: false,
      IPv6Timeout: 300,
      UseHosts: true,
      UseSystemHosts: true,
      RespectRules: false,
      NameServer: [
        "223.5.5.5",
        "119.29.29.29",
        "8.8.8.8",
        "8.8.4.4",
        "1.0.0.1",
        "tls://8.8.4.4",
        "tls://1.1.1.1",
        "tls://223.5.5.5:853",
        "https://dns.alidns.com/dns-query#h3=true",
        "https://mozilla.cloudflare-dns.com/dns-query#DNS&h3=true",
        "quic://dns.adguard.com:784",
        "system",
      ],
      Fallback: [
        /*"tls://223.5.5.5:853",
        "https://dns.alidns.com/dns-query#h3=true",
        "https://cloudflare-dns.com/dns-query",
        "https://1.12.12.12/dns-query",
        "https://120.53.53.53/dns-query"*/
      ],
      FallbackFilter: RawFallbackFilter.by(GeoIP: false),
      Listen: null,
      EnhancedMode: ClashDnsEnhancedMode.fakeIp.name,
      FakeIPRange: "$_gateWay.1/16",
      FakeIPFilter: [
        "*.lan",
        "*.local",
        "time.*.com",
        "time.*.gov",
        "time.*.edu.cn",
        "time.*.apple.com",
        "time-ios.apple.com",
        "time1.*.com",
        "time2.*.com",
        "time3.*.com",
        "time4.*.com",
        "time5.*.com",
        "time6.*.com",
        "time7.*.com",
        "ntp.*.com",
        "ntp1.*.com",
        "ntp2.*.com",
        "ntp3.*.com",
        "ntp4.*.com",
        "ntp5.*.com",
        "ntp6.*.com",
        "ntp7.*.com",
        "*.time.edu.cn",
        "*.ntp.org.cn",
        "*.pool.ntp.org",
        "+.services.googleapis.cn",
        "+.push.apple.com",
        "time1.cloud.tencent.com",
        "localhost.ptlogin2.qq.com",
        "+.stun.*.*",
        "+.stun.*.*.*",
        "+.stun.*.*.*.*",
        "+.stun.*.*.*.*.*",
        "lens.l.google.com",
        "*.n.n.srv.nintendo.net",
        "+.stun.playstation.net",
        "xbox.*.*.microsoft.com",
        "*.*.xboxlive.com",
        "*.msftncsi.com",
        "*.msftconnecttest.com",
        "*.mcdn.bilivideo.cn",
        "WORKGROUP",
      ],
      FakeIPFilterMode: ClashFakeIPFilterMode.blacklist.name,
      DefaultNameserver: [
        "223.5.5.5",
        "119.29.29.29",
        "8.8.8.8",
        "8.8.4.4",
        "1.0.0.1",
        "system",
      ],
      CacheAlgorithm: ClashDnsCacheAlgorithm.arc.name,
      NameServerPolicy: {},
      ProxyServerNameserver: [
        /*"tls://8.8.4.4",
        "tls://1.1.1.1",
        "tls://223.5.5.5:853",
        "https://dns.alidns.com/dns-query#h3=true",*/
      ],
      DirectNameServer: [],
      DirectNameServerFollowPolicy: false,
    );
  }

  static RawNTP defaultNTP() {
    return RawNTP.by(OverWrite: false, Enable: false);
  }

  static RawGeoXUrl defaultGeoXUrl() {
    return RawGeoXUrl.by(
        OverWrite: true,
        GeoIp:
            "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat",
        Mmdb:
            "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb",
        ASN:
            "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb",
        GeoSite:
            "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat");
  }

  static RawSniffer defaultSniffer() {
    return RawSniffer.by(OverWrite: false, Enable: false);
  }

  static RawTLS defaultTLS() {
    return RawTLS.by(
        OverWrite: false,
        Certificate: null,
        PrivateKey: null,
        CustomTrustCert: null);
  }

  static RawExtension defaultExtension() {
    return RawExtension.by(
        Tun: RawExtensionTun.by(
          httpProxy: RawExtensionTunHttpProxy.by(Enable: false),
          perApp: RawExtensionTunPerApp.by(Enable: false),
        ),
        PprofAddr: null,
        DelayTestUrl: "https://www.gstatic.com",
        DelayTestTimeout: 5000);
  }

  static RawConfig defaultConfig() {
    return RawConfig.by(
      IPv6: false,
      LogLevel: ClashLogLevel.error.name,
      Mode: ClashConfigsMode.rule.name,
      MixedPort: 7890,
      ExternalController: "127.0.0.1:9090",
      GlobalClientFingerprint: ClashGlobalClientFingerprint.chrome.name,
      DisableKeepAlive: false,
      KeepAliveInterval: 15,
      DNS: defaultDNS(),
      NTP: defaultNTP(),
      Tun: defaultTun(),
      GeoAutoUpdate: false,
      GeoUpdateInterval: 7 * 24 * 3600,
      GeoXUrl: defaultGeoXUrl(),
      Sniffer: defaultSniffer(),
      TLS: defaultTLS(),
      Extension: defaultExtension(),
    );
  }

  static RawConfig defaultConfigNoOverwrite() {
    return RawConfig.by(
      Mode: _setting.Mode,
      LogLevel: _setting.LogLevel,
      ExternalController: _setting.ExternalController,
      Secret: _setting.Secret,
      DNS: RawDNS.by(
        OverWrite: false,
        Enable: false,
      ),
      NTP: RawNTP.by(OverWrite: false, Enable: false),
      Tun: RawTun.by(OverWrite: false, Enable: false),
      GeoXUrl: RawGeoXUrl.by(),
      Sniffer: RawSniffer.by(OverWrite: false, Enable: false),
      TLS: RawTLS.by(OverWrite: false),
      Extension: RawExtension.by(
        Tun: RawExtensionTun.by(
          httpProxy: RawExtensionTunHttpProxy.by(Enable: false),
          perApp: _setting.Extension?.Tun.perApp ??
              RawExtensionTunPerApp.by(Enable: false),
        ),
        PprofAddr: _setting.Extension?.PprofAddr,
      ),
    );
  }

  static Future<void> uninit() async {}
  static Future<void> initGeo() async {
    const mmdbFileName = "geoip.metadb";
    const asnFileName = "ASN.mmdb";
    const geoIpFileName = "GeoIP.dat";
    const geoSiteFileName = "GeoSite.dat";

    final homePath = await PathUtils.profileDir();
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(
          path.join(homePath, geoFileName),
        );
        final isExists = await geoFile.exists();
        if (isExists) {
          continue;
        }
        final data = await rootBundle.load('assets/datas/$geoFileName');
        List<int> bytes = data.buffer.asUint8List();
        await geoFile.writeAsBytes(bytes, flush: true);
      }
    } catch (err) {
      Log.w("ClashSettingManager.initGeo exception ${err.toString()} ");
    }
  }

  static Future<void> saveSetting() async {
    String filePath = await PathUtils.serviceCoreSettingFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final map = _setting.toJson();
    MapHelper.removeNullOrEmpty(map, false, false);
    String content = encoder.convert(map);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {}
  }

  static Future<String> getPatchContent(bool overwrite) async {
    if (overwrite) {
      final map = _setting.toJson();
      MapHelper.removeNullOrEmpty(map, true, true);
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String content = encoder.convert(map);
      return content;
    }
    return getPatchFinalContent();
  }

  static String getPatchFinalContent() {
    final setting = defaultConfigNoOverwrite();
    final map = setting.toJson();
    MapHelper.removeNullOrEmpty(map, true, true);
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(map);
    return content;
  }

  static Future<void> saveCorePatchFinal(bool overwrite) async {
    final content = await getPatchContent(overwrite);
    String filePath = await PathUtils.serviceCorePatchFinalPath();
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {}
  }

  static Future<void> loadSetting() async {
    String filePath = await PathUtils.serviceCoreSettingFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      try {
        String content = await file.readAsString();
        if (content.isNotEmpty) {
          await _load(content);
        }
      } catch (err, stacktrace) {
        Log.w("ClashSettingManager.loadSetting exception ${err.toString()} ");
      }
    }
    await _initFixed();
  }

  static Future<void> _load(String content) async {
    late RawConfig setting;
    try {
      var config = jsonDecode(content);
      setting = RawConfig.fromJson(config);
    } catch (err, stacktrace) {
      Log.w("ClashSettingManager.load exception ${err.toString()} ");
      return;
    }
    _setting = setting;
    _setting.DNS ??= defaultDNS();
    _setting.NTP ??= defaultNTP();
    _setting.Tun ??= defaultTun();

    _setting.GeoXUrl ??= defaultGeoXUrl();
    _setting.Sniffer ??= defaultSniffer();
    _setting.TLS ??= defaultTLS();
    _setting.Extension ??= defaultExtension();
  }

  static Future<void> _initFixed() async {
    _setting.Secret = await ClashHttpApi.getSecret();
    _setting.GeodataMode = true;
    _setting.GeodataLoader = "memconservative";
    _setting.UnifiedDelay = true;
    _setting.ExternalUI = "";
    _setting.ExternalUIName = "";
    _setting.ExternalUIURL = "";
    _setting.ExternalControllerCors = null;
    _setting.Tun?.Device = AppUtils.getName();
    _setting.Tun?.AutoRedirect = Platform.isLinux;
    _setting.Tun?.AutoRoute = !Platform.isAndroid;
    _setting.Tun?.AutoDetectInterface = !Platform.isAndroid;
    _setting.Profile = RawProfile.by(StoreSelected: true, StoreFakeIP: true);
    _setting.FindProcessMode = Platform.isIOS
        ? ClashFindProcessMode.off.name
        : ClashFindProcessMode.strict.name;
  }

  static Future<ReturnResultError?> setConfigsMode(
      ClashConfigsMode mode) async {
    _setting.Mode = mode.name;
    await saveSetting();

    bool run = await VPNService.getStarted();
    if (!run) {
      return null;
    }
    return await ClashHttpApi.setConfigsMode(mode.name);
  }

  static ClashConfigsMode getConfigsMode() {
    for (var i = 0; i <= ClashConfigsMode.direct.index; ++i) {
      ClashConfigsMode type = ClashConfigsMode.values[i];
      if (type.name == _setting.Mode) {
        return type;
      }
    }

    return ClashConfigsMode.rule;
  }

  static RawConfig getConfig() {
    return _setting;
  }

  static void reset() {
    _setting = defaultConfig();
    _initFixed();
  }

  static int getControlPort() {
    final parts = _setting.ExternalController?.split(':');
    if (parts?.length == 2) {
      return int.tryParse(parts![1]) ?? 0;
    }
    return 0;
  }

  static int? getMixedPort() {
    return null;
  }
}
