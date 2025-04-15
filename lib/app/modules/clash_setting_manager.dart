// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/clash/clash_http_api.dart';
import 'package:clashmi/app/utils/app_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';

class ClashSettingManager {
  static RawConfig _setting = defaultConfig();

  static Future<void> init() async {
    ClashHttpApi.getControlPort = () {
      return getControlPort();
    };
    await loadFromSetting();

    await initGeo();
  }

  static RawConfig defaultConfig() {
    return RawConfig.by(
      IPv6: false,
      LogLevel: ClashLogLevel.debug.name,
      Mode: ClashConfigsMode.rule.name,
      MixedPort: 7890,
      ExternalController: "127.0.0.1:9090",
      GlobalClientFingerprint: ClashGlobalClientFingerprint.chrome.name,
      DNS: RawDNS.by(
        Enable: true,
        IPv6: false,
        UseHosts: true,
        UseSystemHosts: true,
        NameServer: [
          "tls://8.8.4.4",
          "tls://1.1.1.1",
          "tls://223.5.5.5:853",
          "https://dns.alidns.com/dns-query#h3=true",
          "https://mozilla.cloudflare-dns.com/dns-query#DNS&h3=true",
          "quic://dns.adguard.com:784",
        ],
        DefaultNameserver: [
          "114.114.114.114",
          "8.8.8.8",
          "223.5.5.5",
          "119.29.29.29",
        ],
        NameServerPolicy: {
          "www.baidu.com": "114.114.114.114",
          "+.internal.crop.com": "10.0.0.1",
        },
        ProxyServerNameserver: [
          "tls://8.8.4.4",
          "tls://1.1.1.1",
          "tls://223.5.5.5:853",
          "https://dns.alidns.com/dns-query#h3=true",
        ],
        Fallback: [
          "tls://223.5.5.5:853",
          "https://dns.alidns.com/dns-query#h3=true",
          "https://cloudflare-dns.com/dns-query",
          "https://1.12.12.12/dns-query",
          "https://120.53.53.53/dns-query"
        ],
        FallbackFilter: RawFallbackFilter.by(GeoIP: false),
        EnhancedMode: ClashDnsEnhancedMode.fakeIp.name,
        FakeIPRange: "172.19.0.1/16",
        FakeIPFilterMode: ClashFakeIPFilterMode.blacklist.name,
        FakeIPFilter: [
          "*.lan",
          "localhost.ptlogin2.qq.com",
        ],
      ),
      NTP: RawNTP.by(Enable: null),
      Tun: RawTun.by(
          Enable:
              true, //Platform.isAndroid || Platform.isIOS || Platform.isMacOS,
          Stack: "gvisor",
          MTU: 9000,
          Inet4Address: ["172.19.0.1/30"],
          DNSHijack: ["172.19.0.2:53"]),
      GeoAutoUpdate: false,
      GeoUpdateInterval: 7 * 24 * 3600,
      GeoXUrl: RawGeoXUrl.by(
          GeoIp:
              "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat",
          Mmdb:
              "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb",
          ASN:
              "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb",
          GeoSite:
              "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"),
      Sniffer: RawSniffer.by(Enable: null),
      TLS:
          RawTLS.by(Certificate: null, PrivateKey: null, CustomTrustCert: null),
      Extension: RawExtension.by(
          Tun: RawExtensionTun.by(
            HttpProxyEnable: null,
            HttpProxyServer: "127.0.0.1",
          ),
          PprofAddr: "127.0.0.1:4578",
          DelayTestUrl: "https://www.gstatic.com",
          DelayTestTimeout: 5000),
    );
  }

  static Future<RawConfig> defaultConfigNoOverwrite() async {
    return RawConfig.by(
      Mode: _setting.Mode,
      ExternalController: _setting.ExternalController,
      Secret: await ClashHttpApi.getSecret(),
      DNS: RawDNS.by(
        Enable: null,
      ),
      NTP: RawNTP.by(Enable: null),
      Tun: RawTun.by(Enable: null),
      GeoXUrl: RawGeoXUrl.by(),
      Sniffer: RawSniffer.by(Enable: null),
      TLS: RawTLS.by(),
      Extension:
          RawExtension.by(Tun: RawExtensionTun.by(HttpProxyEnable: null)),
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
    _setting.Extension.Tun.HttpProxyServerPort = _setting.MixedPort;
    String filePath = await PathUtils.serviceCoreSettingFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(_setting);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {}
  }

  static Future<void> saveSettingNoOverwrite() async {
    final setting = await defaultConfigNoOverwrite();
    String filePath = await PathUtils.serviceCoreSettingNoOverwriteFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(setting);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {}
  }

  static Future<void> loadFromSetting() async {
    String filePath = await PathUtils.serviceCoreSettingFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      try {
        String content = await file.readAsString();
        if (content.isNotEmpty) {
          if (await _load(content)) {
            await _initFixed();
            return;
          }
        }
      } catch (err, stacktrace) {
        Log.w(
            "ClashSettingManager.loadFromSetting exception ${err.toString()} ");
      }
    }
    await loadFromDefault();
  }

  static Future<void> loadFromDefault() async {
    await _load("{}");
    await _initFixed();
  }

  static Future<bool> _load(String content) async {
    bool ok = true;
    try {
      var config = jsonDecode(content);
      _setting = RawConfig.fromJson(config);
    } catch (err, stacktrace) {
      Log.w("ClashSettingManager.load exception ${err.toString()} ");
      ok = false;
    }

    return ok;
  }

  static Future<void> _initFixed() async {
    _setting.Secret = await ClashHttpApi.getSecret();
    _setting.GeodataMode = true;
    _setting.GeodataLoader = null;
    _setting.UnifiedDelay = true;
    _setting.ExternalUIURL = "";
    _setting.ExternalControllerCors = null;
    _setting.Tun.Device = AppUtils.getName();
    _setting.Tun.AutoRoute = !Platform.isAndroid;
    _setting.Tun.AutoDetectInterface = !Platform.isAndroid;
    _setting.Profile = RawProfile.by(StoreSelected: true);
    _setting.FindProcessMode = Platform.isIOS
        ? ClashFindProcessMode.off.name
        : ClashFindProcessMode.strict.name;
  }

  static Future<ReturnResultError?> setConfigsMode(
      ClashConfigsMode mode) async {
    _setting.Mode = mode.name;
    await saveSetting();
    await saveSettingNoOverwrite();
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
