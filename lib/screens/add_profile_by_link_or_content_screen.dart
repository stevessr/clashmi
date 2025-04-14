// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/utils/platform_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:clashmi/screens/theme_config.dart';
import 'package:clashmi/screens/widgets/framework.dart';
import 'package:flutter/material.dart';

class AddProfileByLinkOrContentScreen extends LasyRenderingStatefulWidget {
  static RouteSettings routSettings() {
    return const RouteSettings(name: "AddProfileByLinkOrContentScreen");
  }

  const AddProfileByLinkOrContentScreen({
    super.key,
  });

  @override
  State<AddProfileByLinkOrContentScreen> createState() =>
      _AddProfileByLinkOrContentScreenState();
}

class _AddProfileByLinkOrContentScreenState
    extends LasyRenderingState<AddProfileByLinkOrContentScreen>
    with AfterLayoutMixin {
  final _textControllerLink = TextEditingController();
  final _textControllerRemark = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {}

  @override
  void dispose() {
    _textControllerLink.dispose();
    _textControllerRemark.dispose();
    super.dispose();
  }

  Future<void> onAdd(BuildContext context) async {
    final tcontext = Translations.of(context);
    Text urlText = Text(_textControllerLink.text);
    String url = urlText.data!.trim();
    Text remarkText = Text(_textControllerRemark.text);
    String remark = remarkText.data!.trim();
    _loading = true;
    setState(() {});

    final result = await ProfileManager.addRemoteProfile(url, remark: remark);

    if (!mounted) {
      return;
    }
    _loading = false;
    setState(() {});
    if (result.error == null) {
      await DialogUtils.showAlertDialog(context, tcontext.meta.addSuccess);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
      return;
    }
    if (!mounted) {
      return;
    }

    DialogUtils.showAlertDialog(context, result.error!.message,
        showCopy: true, showFAQ: true, withVersion: true);
  }

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    Size windowSize = MediaQuery.of(context).size;
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: AppBar(),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 50,
                        height: 30,
                        child: Icon(
                          Icons.arrow_back_ios_outlined,
                          size: 26,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: windowSize.width - 50 * 2,
                      child: Text(
                        tcontext.meta.profileAddUrlOrContent,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: ThemeConfig.kFontWeightTitle,
                            fontSize: ThemeConfig.kFontSizeTitle),
                      ),
                    ),
                    _loading
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 12,
                              ),
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: RepaintBoundary(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              SizedBox(
                                width: 12,
                              )
                            ],
                          )
                        : InkWell(
                            onTap: () async {
                              await onAdd(context);
                            },
                            child: Tooltip(
                                message: tcontext.meta.save,
                                child: const SizedBox(
                                  width: 50,
                                  height: 30,
                                  child: Icon(
                                    Icons.done,
                                    size: 26,
                                  ),
                                )),
                          ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                        child: Card(
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                child: SingleChildScrollView(
                                  child: Column(children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 10, 18, 10),
                                      child: SingleChildScrollView(
                                        child: TextField(
                                          textInputAction: TextInputAction.next,
                                          maxLines:
                                              PlatformUtils.isPC() ? 12 : 4,
                                          controller: _textControllerLink,
                                          cursorColor: Colors.black,
                                          decoration: InputDecoration(
                                              labelText: tcontext
                                                  .meta.profileUrlOrContent,
                                              hintText: tcontext
                                                  .meta.profileUrlOrContentHit),
                                          onChanged: (text) {},
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 10, 18, 10),
                                      child: TextField(
                                        textInputAction: TextInputAction.done,
                                        controller: _textControllerRemark,
                                        cursorColor: Colors.black,
                                        decoration: InputDecoration(
                                          labelText: tcontext.meta.remark,
                                          hintText: tcontext.meta.required,
                                          prefixIcon: const Icon(
                                              Icons.edit_note_outlined),
                                        ),
                                        onSubmitted: (String? text) {
                                          FocusScope.of(context).nextFocus();
                                        },
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 200,
                                    )
                                  ]),
                                ))))),
              ],
            ),
          ),
        ));
  }
}
