import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../adaptive/adaptive.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'tracks_strings.dart';

/// Parses `RRGGBB` / `#RRGGBB` (also with a leading alpha byte, which is
/// ignored). Returns an opaque colour or `null`.
Color? parseHexColor(String input) {
  var text = input.trim();
  if (text.startsWith('#')) text = text.substring(1);
  if (text.length == 8) text = text.substring(2);
  if (text.length != 6) return null;
  final rgb = int.tryParse(text, radix: 16);
  if (rgb == null) return null;
  return Color(0xFF000000 | rgb);
}

/// `RRGGBB` of an opaque colour.
String formatHexColor(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();

/// Picks a custom colour with hue / saturation / brightness sliders and a
/// hex field, in a bottom sheet. Returns `null` when cancelled.
Future<Color?> showCustomColorSheet(
  BuildContext context, {
  required Color initial,
}) {
  return showAdaptiveSheet<Color>(
    context,
    builder: (_) => _ColorSheet(initial: initial),
  );
}

class _ColorSheet extends StatefulWidget {
  const _ColorSheet({required this.initial});

  final Color initial;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late final TextEditingController _hex = TextEditingController(
    text: formatHexColor(widget.initial),
  );
  bool _hexValid = true;

  Color get _color => _hsv.toColor();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _hexValid = true;
      _hex.text = formatHexColor(hsv.toColor());
    });
  }

  void _onHexChanged(String text) {
    final color = parseHexColor(text);
    setState(() {
      _hexValid = color != null;
      if (color != null) _hsv = HSVColor.fromColor(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final color = _color;
    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> onChanged,
    ) => Row(
      children: [
        SizedBox(
          width: t.sizes.bigTapTarget + t.space.xl,
          child: Text(label, style: t.text.label),
        ),
        Expanded(
          child: AdaptiveSlider(
            value: value,
            max: max,
            semanticLabel: label,
            onChanged: onChanged,
          ),
        ),
      ],
    );
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            t.space.page,
            0,
            t.space.page,
            t.space.page,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(Strings.pickColor, style: t.text.title),
              ),
              SizedBox(height: t.space.md),
              Container(
                height: t.sizes.bigTapTarget,
                decoration: t.surfaceDecoration(color: color),
              ),
              SizedBox(height: t.space.md),
              slider(
                TracksStrings.hue,
                _hsv.hue,
                360,
                (v) => _setHsv(_hsv.withHue(v.clamp(0, 360).toDouble())),
              ),
              slider(
                TracksStrings.saturation,
                _hsv.saturation,
                1,
                (v) => _setHsv(_hsv.withSaturation(v.clamp(0, 1).toDouble())),
              ),
              slider(
                TracksStrings.brightness,
                _hsv.value,
                1,
                (v) => _setHsv(_hsv.withValue(v.clamp(0, 1).toDouble())),
              ),
              SizedBox(height: t.space.sm),
              if (isCupertino(context))
                CupertinoTextField(
                  controller: _hex,
                  placeholder: Strings.hexColor,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _onHexChanged,
                )
              else
                TextField(
                  controller: _hex,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: Strings.hexColor,
                    errorText: _hexValid ? null : TracksStrings.hexInvalid,
                  ),
                  onChanged: _onHexChanged,
                ),
              if (isCupertino(context) && !_hexValid)
                Padding(
                  padding: EdgeInsets.only(top: t.space.xs),
                  child: Text(
                    TracksStrings.hexInvalid,
                    style: t.text.caption.copyWith(color: t.colors.danger),
                  ),
                ),
              SizedBox(height: t.space.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdaptiveTextButton(
                    label: Strings.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: t.space.sm),
                  AdaptiveFilledButton(
                    label: Strings.done,
                    onPressed: _hexValid
                        // Read at press time: a tap can arrive before the
                        // frame that follows the last keystroke.
                        ? () => Navigator.of(context).pop(_color)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
