import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SegemntedElevatedButtonItem {
  SegemntedElevatedButtonItem({required this.value, required this.text});
  final int value;
  final String text;
}

class SegmentedElevatedButton extends StatefulWidget {
  const SegmentedElevatedButton(
      {super.key,
      required this.segments,
      required this.selected,
      this.padding,
      this.background,
      this.buttonStyle,
      this.onPressed});

  final List<SegemntedElevatedButtonItem> segments;
  final int selected;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final ButtonStyle? buttonStyle;
  final Function(int value)? onPressed;

  @override
  State<SegmentedElevatedButton> createState() => _SegmentedElevatedButton();
}

class _SegmentedElevatedButton extends State<SegmentedElevatedButton> {
  final List<WidgetStatesController> _controllers = [];
  @override
  Widget build(BuildContext context) {
    var themes = Provider.of<Themes>(context, listen: false);
    Color? color = themes.getThemeHomeColor(context);
    if (_controllers.isEmpty) {
      for (int i = 0; i < widget.segments.length; ++i) {
        var controller = WidgetStatesController();
        if (i == widget.selected) {
          controller.value = {WidgetState.selected};
        }
        _controllers.add(controller);
      }
    }
    List<Widget> widgets = [];
    for (int i = 0; i < widget.segments.length; ++i) {
      widgets.add(ElevatedButton(
        statesController: _controllers[i],
        style: widget.buttonStyle ??
            ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.focused)) {
                    return Colors.white;
                  }
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withOpacity(0.3);
                },
              ),
              shadowColor: WidgetStateProperty.resolveWith(
                (Set<WidgetState> states) {
                  return Colors.white.withOpacity(0.0);
                },
              ),
            ),
        onPressed: () async {
          for (int j = 0; j < widget.segments.length; ++j) {
            _controllers[j].value = i == j ? {WidgetState.selected} : {};
          }

          widget.onPressed?.call(i);
          setState(() {});
        },
        child: Text(
          widget.segments[i].text,
          style: TextStyle(
              color: _controllers[i].value.contains(WidgetState.selected)
                  ? ThemeDefine.kColorBlue
                  : Colors.black),
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: widget.background ?? color,
        borderRadius: BorderRadius.all(Radius.circular(25)),
      ),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.fromLTRB(0, 3, 0, 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: widgets,
        ),
      ),
    );
  }
}
