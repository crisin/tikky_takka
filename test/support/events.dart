import 'package:tikky_takka/core/domain/domain.dart';

/// Builds event lists for engine tests with auto-incrementing ids and seq.
class EventLog {
  EventLog({this.sessionId = 's1', this.trackId = 't1'});

  final String sessionId;
  final String trackId;
  final List<TrackEvent> events = [];
  int _seq = 0;

  TrackEvent add(
    EventType type,
    int at, {
    String? label,
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
    int? seq,
    JsonMap extra = const {},
  }) {
    final event = TrackEvent(
      id: 'e${_seq.toString().padLeft(3, '0')}',
      sessionId: sessionId,
      trackId: trackId,
      type: type,
      at: at,
      seq: seq ?? _seq,
      label: label,
      personId: personId,
      substanceId: substanceId,
      amount: amount,
      note: note,
      extra: extra,
    );
    _seq++;
    events.add(event);
    return event;
  }

  void start(int at) => add(EventType.start, at);
  void pause(int at) => add(EventType.pause, at);
  void resume(int at) => add(EventType.resume, at);
  void lap(int at, {String? label}) => add(EventType.lap, at, label: label);
  void tick(int at, {String? label}) => add(EventType.tick, at, label: label);
  void ack(int at) => add(EventType.ack, at);
  void stop(int at) => add(EventType.stop, at);
  void extend(int at, int ms) =>
      add(EventType.extend, at, extra: {TrackEvent.extendKey: ms});
  void skip(int at) => add(EventType.skip, at);
  void entry(int at, {String? person, String? substance, String? amount}) =>
      add(
        EventType.entry,
        at,
        personId: person,
        substanceId: substance,
        amount: amount,
      );
}

const int sec = 1000;
const int min = 60 * sec;
const int hour = 60 * min;
