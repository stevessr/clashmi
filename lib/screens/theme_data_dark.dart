import 'package:clashmi/screens/theme_define.dart';
import 'package:flutter/material.dart';

class ThemeDataDark {
  static ThemeData theme(BuildContext context) {
    final color = const Color(0xff121212);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF293CA0),
      brightness: Brightness.dark,
      surface: color,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      platform: TargetPlatform.iOS,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: Colors.grey),
        floatingLabelStyle: TextStyle(color: ThemeDefine.kColorBlue),
        helperStyle: TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey),
        errorStyle: TextStyle(color: Colors.red),
        isDense: true,
        contentPadding: EdgeInsets.all(8),
        border: OutlineInputBorder(
            borderSide: BorderSide(color: ThemeDefine.kColorBlue),
            borderRadius: BorderRadius.all(Radius.circular(4))),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: ThemeDefine.kColorBlue),
            borderRadius: BorderRadius.all(Radius.circular(4))),
      ),
      listTileTheme: ListTileThemeData(dense: true),
    );
  }
}
