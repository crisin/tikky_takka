import '../../../../core/domain/domain.dart';
import '../../../../l10n/strings.dart';

/// The name of a thing counted by `entryThingKey`: the substance, else the
/// amount, else "Ohne Angabe".
String thingLabel(String key, Map<String, Substance> substances) {
  if (key.startsWith('s:')) {
    return substances[key.substring(2)]?.name ?? Strings.unknown;
  }
  final amount = key.length > 2 ? key.substring(2) : '';
  return amount.isEmpty ? Strings.protocolNoSubstance : amount;
}

/// The colour of a thing (ARGB); `null` = none of its own.
int? thingColor(String key, Map<String, Substance> substances) =>
    key.startsWith('s:') ? substances[key.substring(2)]?.color : null;
