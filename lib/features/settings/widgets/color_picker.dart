import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../adaptive/adaptive.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../color_utils.dart';
import '../settings_strings.dart';
import 'setting_rows.dart';

/// An inline colour picker without extra packages: hex field, three
/// platform sliders (hue, saturation, brightness) and quick swatches.
///
/// [onChanged] fires for every intermediate value (use it for the live
/// preview), [onChangeEnd] once a value is settled (slider released, valid
/// hex typed, swatch tapped) - persist there.
class ColorPickerPanel extends StatefulWidget {
  const ColorPickerPanel({
    required this.color,
    required this.onChanged,
    this.onChangeEnd,
    this.swatches = const [],
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color>? onChangeEnd;

  /// Quick choices (e.g. the other colours of the theme).
  final List<Color> swatches;

  @override
  State<ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends State<ColorPickerPanel> {
  late HSVColor _hsv = HSVColor.fromColor(_opaque(widget.color));
  late final TextEditingController _hex = TextEditingController(
    text: colorToHex(widget.color),
  );
  final FocusNode _hexFocus = FocusNode();
  bool _hexInvalid = false;

  static Color _opaque(Color color) => color.withValues(alpha: 1);

  Color get _color => _hsv.toColor();

  @override
  void didUpdateWidget(ColorPickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changed from outside (reset, undo): take the new colour over. The
    // local HSV value is kept otherwise, so that hue and saturation do not
    // jump while brightness or saturation sit at zero.
    final incoming = _opaque(widget.color).toARGB32();
    if (incoming != _color.toARGB32()) {
      _hsv = HSVColor.fromColor(_opaque(widget.color));
      if (!_hexFocus.hasFocus) _hex.text = colorToHex(widget.color);
      _hexInvalid = false;
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor next, {required bool settled}) {
    setState(() {
      _hsv = next;
      _hexInvalid = false;
      _hex.text = colorToHex(next.toColor());
    });
    widget.onChanged(next.toColor());
    if (settled) widget.onChangeEnd?.call(next.toColor());
  }

  void _onHexChanged(String text) {
    // Only complete values count while typing; the short `#RGB` form is
    // accepted on submit.
    final digits = text.replaceAll('#', '').trim().length;
    if (digits != 6 && digits != 8) {
      if (_hexInvalid) setState(() => _hexInvalid = false);
      return;
    }
    final parsed = parseHexColor(text);
    if (parsed == null) {
      setState(() => _hexInvalid = true);
      return;
    }
    setState(() {
      _hexInvalid = false;
      _hsv = HSVColor.fromColor(parsed);
    });
    widget.onChanged(parsed);
    widget.onChangeEnd?.call(parsed);
  }

  void _onHexSubmitted(String text) {
    final parsed = parseHexColor(text);
    if (parsed == null) {
      setState(() => _hexInvalid = true);
      return;
    }
    setState(() {
      _hexInvalid = false;
      _hsv = HSVColor.fromColor(parsed);
      _hex.text = colorToHex(parsed);
    });
    widget.onChanged(parsed);
    widget.onChangeEnd?.call(parsed);
  }

  void _pick(Color color) =>
      _setHsv(HSVColor.fromColor(_opaque(color)), settled: true);

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final color = _color;
    final formatters = [
      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
      LengthLimitingTextInputFormatter(9),
    ];
    final Widget hexField = isCupertino(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: _hex,
                focusNode: _hexFocus,
                placeholder: Strings.hexColor,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: formatters,
                textInputAction: TextInputAction.done,
                onChanged: _onHexChanged,
                onSubmitted: _onHexSubmitted,
              ),
              if (_hexInvalid)
                Padding(
                  padding: EdgeInsets.only(top: t.space.xs),
                  child: Text(
                    SettingsStrings.hexInvalid,
                    style: t.text.caption.copyWith(color: t.colors.danger),
                  ),
                ),
            ],
          )
        : TextField(
            controller: _hex,
            focusNode: _hexFocus,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: formatters,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: Strings.hexColor,
              errorText: _hexInvalid ? SettingsStrings.hexInvalid : null,
              isDense: true,
            ),
            onChanged: _onHexChanged,
            onSubmitted: _onHexSubmitted,
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.sm,
        t.space.page,
        t.space.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ColorSwatchDot(color: color, size: t.sizes.minTapTarget),
              SizedBox(width: t.space.md),
              Expanded(child: hexField),
            ],
          ),
          SizedBox(height: t.space.sm),
          _ChannelSlider(
            label: SettingsStrings.hue,
            valueLabel: SettingsStrings.degrees(_hsv.hue),
            value: _hsv.hue,
            max: 360,
            onChanged: (v) => _setHsv(_hsv.withHue(v), settled: false),
            onChangeEnd: (v) => _setHsv(_hsv.withHue(v), settled: true),
          ),
          _ChannelSlider(
            label: SettingsStrings.saturation,
            valueLabel: SettingsStrings.percentInt(_hsv.saturation),
            value: _hsv.saturation,
            onChanged: (v) => _setHsv(_hsv.withSaturation(v), settled: false),
            onChangeEnd: (v) => _setHsv(_hsv.withSaturation(v), settled: true),
          ),
          _ChannelSlider(
            label: SettingsStrings.brightnessValue,
            valueLabel: SettingsStrings.percentInt(_hsv.value),
            value: _hsv.value,
            onChanged: (v) => _setHsv(_hsv.withValue(v), settled: false),
            onChangeEnd: (v) => _setHsv(_hsv.withValue(v), settled: true),
          ),
          if (widget.swatches.isNotEmpty) ...[
            SizedBox(height: t.space.xs),
            Semantics(
              container: true,
              label: SettingsStrings.swatches,
              child: Wrap(
                children: [
                  for (final swatch in widget.swatches)
                    ColorSwatchDot(
                      color: swatch,
                      semanticLabel: SettingsStrings.swatchLabel(
                        colorToHex(swatch),
                      ),
                      selected: _opaque(swatch).toARGB32() == color.toARGB32(),
                      onTap: () => _pick(swatch),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.max = 1,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.text.caption)),
            Text(valueLabel, style: t.text.caption),
          ],
        ),
        AdaptiveSlider(
          value: value,
          max: max,
          semanticLabel: label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
