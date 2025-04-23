// ignore_for_file: unused_catch_stack

import 'dart:io';

import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/backup_and_sync_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/app/utils/zip_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

class BackupHelper {
  static Future<ReturnResultError?> backupToZip(
      BuildContext context, String zipPath) async {
    var dir = await PathUtils.profileDir();
    var fileList = BackupAndSyncUtils.getZipFileNameList();
    List<String> zipFileList = [];
    try {
      for (var file in fileList) {
        var filePath = path.join(dir, file.item1);
        if (file.item2) {
          final d = Directory(filePath);
          final f = File(filePath);
          bool fexist = await f.exists();
          bool dexist = await d.exists() && (await d.list().length > 0);
          if (!fexist && !dexist) {
            if (!context.mounted) {
              return ReturnResultError("$filePath not exist");
            }
            final tcontext = Translations.of(context);
            return ReturnResultError(tcontext.meta.fileNotExist(p: filePath));
          }
          zipFileList.add(filePath);
        }
      }
      var error = await ZipUtils.zip(zipFileList, zipPath);
      return error;
    } catch (err) {
      return ReturnResultError(err.toString());
    }
  }

  static Future<ReturnResultError?> reloadFromZip(String zipPath) async {
    var result = await BackupAndSyncUtils.validZip(zipPath);
    if (result != null) {
      return result;
    }
    var dir = await PathUtils.profileDir();
    var error = await ZipUtils.unzip(zipPath, dir);
    if (error != null) {
      return error;
    }

    await SettingManager.reload();
    await ClashSettingManager.reload();
    await ProfileManager.reload();

    return null;
  }

  static Future<void> backupRestoreFromZip(
      BuildContext context, String zipPath) async {
    if (!context.mounted) {
      return;
    }
    final tcontext = Translations.of(context);

    var error = await reloadFromZip(zipPath);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      DialogUtils.showAlertDialog(context, error.message,
          showCopy: true, showFAQ: true, withVersion: true);
    } else {
      DialogUtils.showAlertDialog(context, tcontext.meta.importSuccess);
    }
  }
}
