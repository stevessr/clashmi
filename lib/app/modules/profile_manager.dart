// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashmi/app/modules/profile_patch_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/app/utils/date_time_utils.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/http_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/app_lifecycle_state_notify.dart';
import 'package:clashmi/app/utils/download_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:libclash_vpn_service/state.dart';
import 'package:tuple/tuple.dart';

const int kRemarkMaxLength = 32;

class ProfileSetting {
  ProfileSetting({this.id = "", this.remark = "", this.update, this.url = ""});
  String id = "";
  String remark = "";
  String patch = "";
  DateTime? update;
  String url;
  num upload = 0;
  num download = 0;
  num total = 0;
  String expire = "";
  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
        'patch': patch,
        'update': update.toString(),
        'url': url,
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    id = map['id'] ?? '';
    remark = map['remark'] ?? '';
    patch = map['patch'] ?? '';
    final updateTime = map['update'];
    if (updateTime is String) {
      update = DateTime.tryParse(updateTime);
    }
    url = map['url'] ?? '';
    upload = map['upload'] ?? 0;
    download = map['download'] ?? 0;
    total = map['total'] ?? 0;
    expire = map['expire'] ?? "";
  }

  String getType() {
    if (url.isNotEmpty) {
      return "URL";
    }
    return "Local";
  }

  bool isRemote() {
    return url.isNotEmpty;
  }

  String getShowName() {
    return remark.isEmpty ? id : "$remark [$id]";
  }

  void updateSubscriptionTraffic(HttpHeaders? header) {
    if (header == null) {
      return;
    }
    //subscription-userinfo: upload=9579993656; download=92563554739; total=2684354560000; expire=1695781320
    List<String>? subscription = header["subscription-userinfo"];
    if (subscription == null || subscription.isEmpty) {
      return;
    }
    List<String> items = subscription[0].split(';');
    if (items.isEmpty) {
      return;
    }

    for (var item in items) {
      List<String> subitems = item.split('=');
      if (subitems.length != 2) {
        continue;
      }
      String key = subitems[0].trim();
      num? value = num.tryParse(subitems[1].trim());
      if (value == null) {
        continue;
      }

      switch (key) {
        case "upload":
          upload = value;
          break;
        case "download":
          download = value;
          break;
        case "total":
          total = value;
          break;
        case "expire":
          expire =
              DateTimeUtils.millisecondSecondsToDate((value * 1000).toInt()) ??
                  "";
          break;
      }
    }
  }

  Tuple2<bool, String> getExpireTime(String languageTag) {
    bool expiring = false;
    String expireTime = expire;
    if (expireTime.isNotEmpty) {
      DateTime? date = DateTime.tryParse(expireTime);
      if (date != null) {
        try {
          var dif = date.difference(DateTime.now());
          if (dif.inDays <= 14) {
            expiring = true;
          }
          if (languageTag.isNotEmpty) {
            expireTime = DateFormat.yMd(languageTag).format(date);
          }
        } catch (e) {}
      }
    }

    return Tuple2(expiring, expireTime);
  }
}

class ProfileConfig {
  String _currentId = "";
  List<ProfileSetting> profiles = [];

  Map<String, dynamic> toJson() =>
      {'current_id': _currentId, 'profiles': profiles};

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    _currentId = map['current_id'] ?? '';
    final p = map['profiles'];
    if (p is List) {
      for (var value in p) {
        ProfileSetting ps = ProfileSetting();
        ps.fromJson(value);
        profiles.add(ps);
      }
    }
  }
}

class ProfileManager {
  static const String yamlExtension = "yaml";
  static const String urlComment = "#url:";
  static final ProfileConfig _profileConfig = ProfileConfig();

  static final List<void Function(String)> onEventCurrentChanged = [];
  static final List<void Function(String)> onEventAdd = [];
  static final List<void Function(String)> onEventRemove = [];
  static final List<void Function(String, bool)> onEventUpdate = [];
  static final Set<String> updating = {};
  static bool _saving = false;

  static Future<void> init() async {
    await load();
    VPNService.onEventStateChanged
        .add((FlutterVpnServiceState state, Map<String, String> params) async {
      if (state == FlutterVpnServiceState.connected) {
        Future.delayed(const Duration(seconds: 3), () async {});
      }
    });
    AppLifecycleStateNofity.onStateResumed(null, () {
      Future.delayed(const Duration(seconds: 3), () async {});
    });
    Future.delayed(const Duration(seconds: 30), () async {});
  }

  static Future<void> uninit() async {}
  static Future<void> reload() async {
    final dir = await PathUtils.profilesDir();
    List<String> ids = [];
    List<String> idsToDelete = [];
    for (var profile in _profileConfig.profiles) {
      ids.add(profile.id);
    }
    _profileConfig._currentId = "";
    _profileConfig.profiles = [];
    await load();
    for (var id in ids) {
      int index = _profileConfig.profiles.indexWhere((value) {
        return value.id == _profileConfig._currentId;
      });
      if (index < 0) {
        idsToDelete.add(id);
      }
    }
    for (var id in idsToDelete) {
      final filePath = path.join(dir, id);
      await FileUtils.deletePath(filePath);
    }
  }

  static Future<void> save() async {
    if (_saving) {
      return;
    }
    _saving = true;
    String filePath = await PathUtils.profilesConfigFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(_profileConfig);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {
      Log.w("ProfileManager.save exception  $filePath ${err.toString()}");
    }
    _saving = false;
  }

  static Future<void> load() async {
    String dir = await PathUtils.profilesDir();
    String filePath = await PathUtils.profilesConfigFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      try {
        String content = await file.readAsString();
        if (content.isNotEmpty) {
          var config = jsonDecode(content);
          _profileConfig.fromJson(config);
        }
      } catch (err, stacktrace) {
        Log.w("ProfileManager.load exception ${err.toString()} ");
      }
    }

    Map<String, String?> existProfiles = {};
    var files =
        FileUtils.recursionFile(dir, extensionFilter: {".yaml", ".yml"});
    for (var file in files) {
      String? line = await FileUtils.readLastLineStartWith(file, urlComment);
      existProfiles[path.basename(file)] =
          line?.substring(urlComment.length).trim();
    }
    for (int i = 0; i < _profileConfig.profiles.length; ++i) {
      if (!existProfiles.containsKey(_profileConfig.profiles[i].id) &&
          !_profileConfig.profiles[i].isRemote()) {
        _profileConfig.profiles.removeAt(i);
        --i;
      }
    }
    existProfiles.forEach((key, value) {
      int index = _profileConfig.profiles.indexWhere((value) {
        return value.id == _profileConfig._currentId;
      });
      if (index < 0) {
        _profileConfig.profiles.add(ProfileSetting(id: key, url: value ?? ""));
      }
    });

    if (_profileConfig._currentId.isNotEmpty) {
      int index = _profileConfig.profiles.indexWhere((value) {
        return value.id == _profileConfig._currentId;
      });

      if (index < 0) {
        _profileConfig._currentId = "";
      }
    }
    if (_profileConfig._currentId.isEmpty &&
        _profileConfig.profiles.isNotEmpty) {
      _profileConfig._currentId = _profileConfig.profiles.first.id;
    }
  }

  static ProfileSetting? getCurrent() {
    if (_profileConfig._currentId.isEmpty) {
      return null;
    }
    int index = _profileConfig.profiles.indexWhere((value) {
      return value.id == _profileConfig._currentId;
    });
    if (index < 0) {
      return null;
    }
    return _profileConfig.profiles[index];
  }

  static Future<ReturnResultError?> prepare(ProfileSetting profile) async {
    String dir = await PathUtils.profilesDir();
    final filePath = path.join(dir, profile.id);
    try {
      if (!await File(filePath).exists()) {
        if (profile.isRemote()) {
          final result = await updateProfile(profile.id);
          if (result == null) {
            return null;
          }
          return ReturnResultError(
              "Profile download failed: ${profile.id} ${result.message}");
        }
        return ReturnResultError("Profile not exist: $filePath");
      }
    } catch (err) {}
    return null;
  }

  static void setCurrent(String id) {
    if (_profileConfig._currentId == id) {
      return;
    }
    int index = _profileConfig.profiles.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return;
    }
    _profileConfig._currentId = id;
    for (var event in onEventCurrentChanged) {
      event(id);
    }
  }

  static void removePatch(String patch) {
    for (var profile in _profileConfig.profiles) {
      if (profile.patch == patch) {
        profile.patch = "";
      }
    }
  }

  static List<ProfileSetting> getProfiles() {
    return _profileConfig.profiles;
  }

  static Future<ReturnResultError?> addLocalProfile(String filePath,
      {String remark = ""}) async {
    final id = "${filePath.hashCode}.yaml";
    final savePath = path.join(await PathUtils.profilesDir(), id);
    final file = File(filePath);
    if (!await file.exists()) {
      return ReturnResultError("file not exist: $filePath");
    }
    try {
      await file.copy(savePath);
      int index = _profileConfig.profiles.indexWhere((value) {
        return value.id == id;
      });
      if (index < 0) {
        _profileConfig.profiles.add(
            ProfileSetting(id: id, remark: remark, update: DateTime.now()));
      } else {
        _profileConfig.profiles[index] =
            ProfileSetting(id: id, remark: remark, update: DateTime.now());
      }

      for (var event in onEventAdd) {
        event(id);
      }

      if (_profileConfig._currentId.isEmpty) {
        setCurrent(id);
      }

      await save();
      return null;
    } catch (err) {
      return ReturnResultError("addLocalProfile exception: ${err.toString()}");
    }
  }

  static Future<ReturnResult<String>> addRemoteProfile(String url,
      {String remark = "", bool overwrite = true}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ReturnResult(error: ReturnResultError("invalid url"));
    }
    final id = "${url.hashCode}.yaml";
    final savePath = path.join(await PathUtils.profilesDir(), id);
    final userAgent = SettingManager.getConfig().userAgent();
    final result =
        await DownloadUtils.downloadWithPort(uri, savePath, userAgent, null);
    if (result.error != null) {
      return ReturnResult(error: result.error);
    }
    await FileUtils.append(savePath, "\n$urlComment$url\n");

    if (remark.isEmpty) {
      final result = await HttpUtils.httpGetTitle(url, userAgent);
      remark = result.data ?? "";
    }

    int index = _profileConfig.profiles.indexWhere((value) {
      return value.id == id;
    });
    final profile = ProfileSetting(
        id: id, remark: remark, update: DateTime.now(), url: url);
    if (!overwrite) {
      profile.patch = kProfilePatchBuildinNoOverwrite;
    }
    profile.updateSubscriptionTraffic(result.data);
    if (index < 0) {
      _profileConfig.profiles.add(profile);
    } else {
      _profileConfig.profiles[index] = profile;
    }

    for (var event in onEventAdd) {
      event(id);
    }

    if (_profileConfig._currentId.isEmpty) {
      setCurrent(id);
    }

    await save();
    return ReturnResult(data: id);
  }

  static Future<void> updateAllProfile() async {
    for (var profile in _profileConfig.profiles) {
      updateProfile(profile.id);
    }
  }

  static Future<ReturnResultError?> updateProfile(String id) async {
    int index = _profileConfig.profiles.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return null;
    }
    ProfileSetting profile = _profileConfig.profiles[index];
    if (!profile.isRemote()) {
      return null;
    }
    final uri = Uri.tryParse(profile.url);
    if (uri == null) {
      return null;
    }
    updating.add(id);
    for (var event in onEventUpdate) {
      event(id, false);
    }
    final userAgent = SettingManager.getConfig().userAgent();
    final savePath = path.join(await PathUtils.profilesDir(), id);
    final result =
        await DownloadUtils.downloadWithPort(uri, savePath, userAgent, null);
    updating.remove(id);
    if (result.error != null) {
      for (var event in onEventUpdate) {
        event(id, true);
      }
      return result.error;
    }
    await FileUtils.append(savePath, "\n$urlComment${profile.url}\n");
    if (profile.remark.isEmpty) {
      final result = await HttpUtils.httpGetTitle(profile.url, userAgent);
      profile.remark = result.data ?? "";
    }
    profile.update = DateTime.now();
    profile.updateSubscriptionTraffic(result.data);
    for (var event in onEventUpdate) {
      event(id, true);
    }
    await save();
    return null;
  }

  static Future<void> removeProfile(String id) async {
    int index = _profileConfig.profiles.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return;
    }
    _profileConfig.profiles.removeAt(index);
    for (var event in onEventRemove) {
      event(id);
    }
    if (_profileConfig._currentId == id) {
      _profileConfig._currentId = _profileConfig.profiles.isEmpty
          ? ""
          : _profileConfig.profiles.first.id;

      for (var event in onEventCurrentChanged) {
        event(_profileConfig._currentId);
      }
    }

    final filePath = path.join(await PathUtils.profilesDir(), id);
    await FileUtils.deletePath(filePath);
    await save();
  }

  static Future<String> getProfilePath(String id) async {
    final filePath = path.join(await PathUtils.profilesDir(), id);
    return filePath;
  }

  static void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex >= _profileConfig.profiles.length ||
        newIndex >= _profileConfig.profiles.length) {
      return;
    }
    var item = _profileConfig.profiles.removeAt(oldIndex);
    _profileConfig.profiles.insert(newIndex, item);
  }
}
