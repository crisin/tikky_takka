import '../../l10n/strings.dart';
import '../domain/domain.dart';
import 'history_math.dart';
import 'summary.dart';
import 'timeline.dart';

// The timeline and the exports work on tracks, each with its sessions and
// events. The protocol is no longer a track: its entries belong to persons.
// Where it has to appear among the tracks it is shown as ONE lane
// ("Protokoll") with one open session, built here from the entries.
// Nothing of it is stored.

/// Id of the protocol lane, and of its session.
const String protocolLaneId = 'protocol';

/// The lane that carries the entries of the protocol.
Track protocolLane(String setId) => Track(
  id: protocolLaneId,
  setId: setId,
  name: Strings.modeName(TrackMode.protocol),
  config: const ProtocolConfig(),
);

/// Whether [track] is the lane built by [protocolLane].
bool isProtocolLane(Track? track) => track?.id == protocolLaneId;

/// [entry] as an event of the protocol lane; it keeps the id of the entry.
TrackEvent entryAsEvent(Entry entry) => TrackEvent(
  id: entry.id,
  sessionId: protocolLaneId,
  trackId: protocolLaneId,
  type: EventType.entry,
  at: entry.at,
  personId: entry.personId,
  substanceId: entry.substanceId,
  amount: entry.amount,
  note: entry.note,
  createdAt: entry.createdAt,
  updatedAt: entry.updatedAt,
);

/// The [entries] as the one session of the protocol lane, or `null`
/// without entries.
HistorySession? entriesAsSession(
  String setId,
  Iterable<Entry> entries,
  int nowMs, {
  TrackSet? set,
}) {
  final events = [for (final e in entries) entryAsEvent(e)]
    ..sort(compareEvents);
  if (events.isEmpty) return null;
  const config = ProtocolConfig();
  return HistorySession(
    session: Session(
      id: protocolLaneId,
      trackId: protocolLaneId,
      config: config,
      startedAt: events.first.at,
    ),
    events: List.unmodifiable(events),
    summary: summarizeSession(config: config, events: events, nowMs: nowMs),
    track: protocolLane(setId),
    set: set,
  );
}
