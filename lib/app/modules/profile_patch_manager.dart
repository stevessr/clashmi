// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

const int kRemarkMaxLength = 32;
const String kProfilePatchBuildinOverwrite = "profile_patch_buildin_overwrite";
const String kProfilePatchBuildinNoOverwrite =
    "profile_patch_buildin_no_overwrite";

class ProfilePatchSetting {
  ProfilePatchSetting({this.id = "", this.remark = ""});
  String id = "";
  String remark = "";

  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
      };
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    id = map['id'] ?? '';
    remark = map['remark'] ?? '';
  }

  String getShowName(BuildContext context) {
    final tcontext = Translations.of(context);
    if (id.isEmpty || id == kProfilePatchBuildinOverwrite) {
      return tcontext.profilePatchMode.overwrite;
    }
    if (id == kProfilePatchBuildinNoOverwrite) {
      return tcontext.profilePatchMode.noOverwrite;
    }
    return remark;
  }
}

class ProfilePatchConfig {
  String _currentId = "";
  List<ProfilePatchSetting> profilePatchs = [];

  Map<String, dynamic> toJson() =>
      {'current_id': _currentId, 'profile_patchs': profilePatchs};

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    _currentId = map['current_id'] ?? '';
    final p = map['profile_patchs'];
    if (p is List) {
      for (var value in p) {
        ProfilePatchSetting ps = ProfilePatchSetting();
        ps.fromJson(value);
        profilePatchs.add(ps);
      }
    }
  }
}

class ProfilePatchManager {
  static const String yamlExtension = "yaml";

  static final ProfilePatchConfig _profilePatchConfig = ProfilePatchConfig();

  static final List<void Function(String)> onEventCurrentChanged = [];
  static final List<void Function(String)> onEventAdd = [];
  static final List<void Function(String)> onEventRemove = [];
  static bool _saving = false;

  static Future<void> init() async {
    await load();
  }

  static Future<void> uninit() async {}
  static Future<void> reload() async {
    final dir = await PathUtils.profilePatchsDir();
    List<String> ids = [];
    List<String> idsToDelete = [];
    for (var profile in _profilePatchConfig.profilePatchs) {
      ids.add(profile.id);
    }
    _profilePatchConfig._currentId = kProfilePatchBuildinOverwrite;
    _profilePatchConfig.profilePatchs = [];
    await load();
    for (var id in ids) {
      int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
        return value.id == id;
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
    String filePath = await PathUtils.profilePatchsConfigFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(_profilePatchConfig);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {
      Log.w("ProfilePatchManager.save exception ${err.toString()} ");
    }
    _saving = false;
  }

  static Future<void> load() async {
    String dir = await PathUtils.profilePatchsDir();
    String filePath = await PathUtils.profilePatchsConfigFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      try {
        String content = await file.readAsString();
        if (content.isNotEmpty) {
          var config = jsonDecode(content);
          _profilePatchConfig.fromJson(config);
          for (int i = 0; i < _profilePatchConfig.profilePatchs.length; ++i) {
            final filePath =
                path.join(dir, _profilePatchConfig.profilePatchs[i].id);
            try {
              if (!await File(filePath).exists()) {
                _profilePatchConfig.profilePatchs.removeAt(i);
                --i;
              }
            } catch (err) {
              _profilePatchConfig.profilePatchs.removeAt(i);
              --i;
            }
          }
        }
      } catch (err, stacktrace) {
        Log.w("ProfilePatchManager.load exception ${err.toString()} ");
      }
    }
    Set<String> existProfiles = {};

    var files =
        FileUtils.recursionFile(dir, extensionFilter: {".yaml", ".yml"});
    for (var file in files) {
      existProfiles.add(path.basename(file));
    }
    for (int i = 0; i < _profilePatchConfig.profilePatchs.length; ++i) {
      if (!existProfiles.contains(_profilePatchConfig.profilePatchs[i].id)) {
        _profilePatchConfig.profilePatchs.removeAt(i);
        --i;
      }
    }
    for (var value in existProfiles) {
      int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
        return value.id == _profilePatchConfig._currentId;
      });
      if (index < 0) {
        _profilePatchConfig.profilePatchs
            .add(ProfilePatchSetting(id: value, remark: value));
      }
    }

    if (_profilePatchConfig._currentId.isNotEmpty) {
      int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
        return value.id == _profilePatchConfig._currentId;
      });

      if (index < 0) {
        _profilePatchConfig._currentId = kProfilePatchBuildinOverwrite;
      }
    }
  }

  static ProfilePatchSetting getCurrent() {
    if (_profilePatchConfig._currentId.isEmpty ||
        _profilePatchConfig._currentId == kProfilePatchBuildinOverwrite) {
      return ProfilePatchSetting(id: kProfilePatchBuildinOverwrite, remark: "");
    }
    if (_profilePatchConfig._currentId == kProfilePatchBuildinNoOverwrite) {
      return ProfilePatchSetting(
          id: kProfilePatchBuildinNoOverwrite, remark: "");
    }
    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == _profilePatchConfig._currentId;
    });
    if (index < 0) {
      return ProfilePatchSetting(id: kProfilePatchBuildinOverwrite, remark: "");
    }
    return _profilePatchConfig.profilePatchs[index];
  }

  static void setCurrent(String id) {
    if (_profilePatchConfig._currentId == id) {
      return;
    }
    if (kProfilePatchBuildinOverwrite == id ||
        kProfilePatchBuildinNoOverwrite == id) {
      _profilePatchConfig._currentId = id;
      return;
    }
    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return;
    }
    _profilePatchConfig._currentId = id;
    for (var event in onEventCurrentChanged) {
      event(id);
    }
  }

  static ProfilePatchSetting? getProfilePatch(String id) {
    if (id == kProfilePatchBuildinOverwrite) {
      return ProfilePatchSetting(id: kProfilePatchBuildinOverwrite, remark: "");
    }
    if (id == kProfilePatchBuildinNoOverwrite) {
      return ProfilePatchSetting(
          id: kProfilePatchBuildinNoOverwrite, remark: "");
    }

    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return getCurrent();
    }
    return _profilePatchConfig.profilePatchs[index];
  }

  static bool existProfilePatch(String id) {
    if (id == kProfilePatchBuildinOverwrite) {
      return true;
    }
    if (id == kProfilePatchBuildinNoOverwrite) {
      return true;
    }

    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return false;
    }
    return true;
  }

  static List<ProfilePatchSetting> getProfilePatchs() {
    return _profilePatchConfig.profilePatchs;
  }

  static Future<ReturnResultError?> addProfilePatch(String filePath,
      {String remark = ""}) async {
    final id = "${filePath.hashCode}.yaml";
    final savePath = path.join(await PathUtils.profilePatchsDir(), id);
    final file = File(filePath);
    if (!await file.exists()) {
      return ReturnResultError("file not exist: $filePath");
    }
    try {
      await file.copy(savePath);
      int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
        return value.id == id;
      });
      if (index < 0) {
        _profilePatchConfig.profilePatchs
            .add(ProfilePatchSetting(id: id, remark: remark));
      } else {
        _profilePatchConfig.profilePatchs[index] =
            ProfilePatchSetting(id: id, remark: remark);
      }

      for (var event in onEventAdd) {
        event(id);
      }

      await save();
      return null;
    } catch (err) {
      return ReturnResultError("addLocalProfile exception: ${err.toString()}");
    }
  }

  static Future<void> removeProfilePatch(String id) async {
    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return;
    }
    _profilePatchConfig.profilePatchs.removeAt(index);
    for (var event in onEventRemove) {
      event(id);
    }
    if (_profilePatchConfig._currentId == id) {
      _profilePatchConfig._currentId = _profilePatchConfig.profilePatchs.isEmpty
          ? kProfilePatchBuildinOverwrite
          : _profilePatchConfig.profilePatchs.first.id;

      for (var event in onEventCurrentChanged) {
        event(_profilePatchConfig._currentId);
      }
    }

    final filePath = path.join(await PathUtils.profilePatchsDir(), id);
    await FileUtils.deletePath(filePath);
    await save();
  }

  static Future<String> getProfilePatchPath(String id) async {
    if (id.isEmpty) {
      id = _profilePatchConfig._currentId;
    }
    if (id == kProfilePatchBuildinOverwrite ||
        id == kProfilePatchBuildinNoOverwrite) {
      return "";
    }
    int index = _profilePatchConfig.profilePatchs.indexWhere((value) {
      return value.id == id;
    });
    if (index < 0) {
      return "";
    }

    final filePath = path.join(await PathUtils.profilePatchsDir(), id);
    return filePath;
  }

  static void reset() {
    _profilePatchConfig._currentId = "";
  }
}
