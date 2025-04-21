import 'dart:io';

import 'package:clashmi/app/clash/clash_http_api.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/file_view_screen.dart';
import 'package:clashmi/screens/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

class ProfilesBoardItem extends StatelessWidget {
  const ProfilesBoardItem({
    super.key,
    required this.setting,
    required this.selected,
    required this.onTap,
    required this.onTapMore,
  });

  final ProfileSetting setting;
  final bool selected;
  final Function() onTap;
  final Function() onTapMore;

  @override
  Widget build(BuildContext context) {
    var settings = SettingManager.getConfig();
    bool remote = setting.url != null && setting.url!.isNotEmpty;
    String tranffic = "";
    Tuple2<bool, String>? tranfficExpire;
    String updateInterval = "";

    if (remote) {
      if (setting.upload != 0 || setting.download != 0 || setting.total != 0) {
        String upload =
            ClashHttpApi.convertTrafficToStringDouble(setting.upload);
        String download =
            ClashHttpApi.convertTrafficToStringDouble(setting.download);
        String total = ClashHttpApi.convertTrafficToStringDouble(setting.total);
        tranffic = "↑ $upload ↓ $download/$total";
      }
      if (setting.expire.isNotEmpty) {
        tranfficExpire = setting.getExpireTime(settings.languageTag);
      }
      if (setting.update != null) {
        final interval = DateTime.now().difference(setting.update!);
        if (interval.inDays > 0) {
          updateInterval = "> ${interval.inDays} d";
        } else if (interval.inHours > 0) {
          updateInterval = "> ${interval.inHours} h";
        } else {
          updateInterval = "< 1 h";
        }
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 10,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    setting.getShowName(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? Colors.blue : null),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    remote ? "URL" : "Local",
                    style: TextStyle(
                        color: selected ? Colors.blue : null, fontSize: 12),
                  ),
                ),
                tranffic.isNotEmpty
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          tranffic,
                          style: TextStyle(
                              color: selected ? Colors.blue : null,
                              fontSize: 12),
                        ))
                    : SizedBox.shrink(),
                tranfficExpire != null
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          tranfficExpire.item2,
                          style: TextStyle(
                              color: selected ? Colors.blue : null,
                              fontSize: 12),
                        ))
                    : SizedBox.shrink(),
                SizedBox(
                  height: 10,
                ),
              ],
            ),
            onTap: () {
              onTap();
            },
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            updateInterval,
            textAlign: TextAlign.right,
            style: TextStyle(color: selected ? Colors.blue : null),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: ProfileManager.updating.contains(setting.id)
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: RepaintBoundary(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  child: Icon(
                    Icons.more_vert_outlined,
                    size: 20,
                  ),
                  onTap: () {
                    onTapMore();
                  },
                ),
        )
      ],
    );
  }
}

class ProfilesBoardScreenWidget extends StatefulWidget {
  const ProfilesBoardScreenWidget({super.key, required this.settings});
  final List<ProfileSetting> settings;

  @override
  State<ProfilesBoardScreenWidget> createState() =>
      _ProfilesBoardScreenWidget();
}

class _ProfilesBoardScreenWidget extends State<ProfilesBoardScreenWidget> {
  @override
  Widget build(BuildContext context) {
    final current = ProfileManager.getCurrent();

    var widgets = [];
    for (var setting in widget.settings) {
      final isCurrent = current != null && current.id == setting.id;

      widgets.add(ProfilesBoardItem(
          setting: setting,
          selected: isCurrent,
          onTap: () {
            ProfileManager.setCurrent(setting.id);
            Navigator.of(context).pop();
          },
          onTapMore: () {
            showMore(setting);
          }));
    }

    return Card(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Scrollbar(
          child: ListView.separated(
        itemBuilder: (_, index) {
          return widgets[index];
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(
            height: 1,
            thickness: 0.3,
          );
        },
        itemCount: widgets.length,
      )),
    ));
  }

  void showMore(ProfileSetting setting) {
    final tcontext = Translations.of(context);
    bool remote = setting.url != null && setting.url!.isNotEmpty;
    var widgets = [
      ListTile(
        title: Text(tcontext.meta.view),
        minLeadingWidth: 40,
        onTap: () async {
          Navigator.of(context).pop();
          final path = await ProfileManager.getProfilePath(setting.id);
          final content = await File(path).readAsString();
          if (!mounted) {
            return;
          }
          await Navigator.push(
              context,
              MaterialPageRoute(
                  settings: FileViewScreen.routSettings(),
                  builder: (context) => FileViewScreen(
                        title: setting.getShowName(),
                        content: content,
                      )));
        },
      ),
      remote
          ? ListTile(
              title: Text(tcontext.meta.update),
              minLeadingWidth: 40,
              onTap: () async {
                Navigator.of(context).pop();
                ProfileManager.updateProfile(setting.id);
              },
            )
          : ListTile(
              title: Text(tcontext.meta.edit),
              minLeadingWidth: 40,
              onTap: () async {
                Navigator.of(context).pop();
                final path = await ProfileManager.getProfilePath(setting.id);
                final content = await File(path).readAsString();
                if (!mounted) {
                  return;
                }
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        settings: FileViewScreen.routSettings(),
                        builder: (context) => FileViewScreen(
                              title: setting.getShowName(),
                              content: content,
                              onSave:
                                  (BuildContext context, String content) async {
                                await File(path).writeAsString(content);
                              },
                            )));
              },
            ),
      setting.url != null && setting.url!.isNotEmpty
          ? ListTile(
              title: Text(tcontext.meta.copyUrl),
              minLeadingWidth: 40,
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  Clipboard.setData(ClipboardData(text: setting.url!));
                } catch (e) {}
              },
            )
          : const SizedBox.shrink(),
      ListTile(
        title: Text(tcontext.meta.remove),
        minLeadingWidth: 40,
        onTap: () async {
          Navigator.of(context).pop();
          ProfileManager.removeProfile(setting.id);
        },
      ),
    ];

    showSheet(
      title: setting.id,
      context: context,
      body: SizedBox(
          height: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Scrollbar(
                child: ListView.separated(
              itemBuilder: (BuildContext context, int index) {
                return widgets[index];
              },
              separatorBuilder: (BuildContext context, int index) {
                return const Divider(
                  height: 1,
                  thickness: 0.3,
                );
              },
              itemCount: widgets.length,
            )),
          )),
    );
  }
}
