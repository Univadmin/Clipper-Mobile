import 'dart:async';
import 'package:iclip/models/lighter_series.dart';
import 'package:iclip/repositories/collection_repository.dart';

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository([List<LighterSeries> initial = const []]) {
    for (final s in initial) {
      records[s.id] = s;
    }
  }
  final records = <String, LighterSeries>{};
  final events = StreamController<List<LighterSeries>>.broadcast(sync: true);
  bool failWrites = false;
  Completer<void>? pendingWrite;
  int writeCount = 0;

  Future<void> _beforeWrite() async {
    writeCount++;
    await pendingWrite?.future;
    if (failWrites) throw StateError('offline');
  }

  void publish() => events.add(records.values.toList());
  @override
  Stream<List<LighterSeries>> watchSeries() => Stream.multi((controller) {
    controller.add(records.values.toList());
    final subscription = events.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> addSeries(LighterSeries series) async {
    await _beforeWrite();
    if (records.containsKey(series.id)) throw StateError('collision');
    records[series.id] = series;
    publish();
  }

  @override
  Future<void> updateSeries(LighterSeries series) async {
    await _beforeWrite();
    records[series.id] = series;
    publish();
  }

  @override
  Future<void> deleteSeries(String id) async {
    await _beforeWrite();
    records.remove(id);
    publish();
  }

  @override
  Future<void> setPiece(String seriesId, int slot, bool owned) async {
    await _beforeWrite();
    final s = records[seriesId]!;
    final pieces = {...s.ownedPieces};
    if (owned) {
      pieces.add(slot);
    } else {
      pieces.remove(slot);
    }
    records[seriesId] = s.copyWith(ownedPieces: pieces);
    publish();
  }

  @override
  Future<List<LighterSeries>> getAllSeries() async => records.values.toList();
  Future<void> close() => events.close();
}
