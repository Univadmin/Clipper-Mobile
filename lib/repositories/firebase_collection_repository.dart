import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/lighter_series.dart';
import 'collection_repository.dart';

class FirebaseCollectionRepository implements CollectionRepository {
  final DatabaseReference _ref;

  FirebaseCollectionRepository({String? userId})
      : _ref = FirebaseDatabase.instance
            .ref('collections/${userId ?? 'default'}');

  @override
  Stream<List<LighterSeries>> watchSeries() {
    return _ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <LighterSeries>[];
      if (data is! Map) return <LighterSeries>[];

      final seriesList = <LighterSeries>[];
      for (final entry in data.entries) {
        try {
          final value = entry.value;
          if (value is Map) {
            final jsonMap = <String, dynamic>{};
            for (final kv in value.entries) {
              jsonMap[kv.key.toString()] = kv.value;
            }
            final series = LighterSeries.fromJson(jsonMap);
            seriesList.add(series);
          }
        } catch (e) {
          // Skip invalid entries
          continue;
        }
      }
      return seriesList;
    });
  }

  @override
  Future<void> addSeries(LighterSeries series) async {
    await _ref.child(series.id).set(series.toJson());
  }

  @override
  Future<void> updateSeries(LighterSeries series) async {
    await _ref.child(series.id).update(series.toJson());
  }

  @override
  Future<void> deleteSeries(String id) async {
    await _ref.child(id).remove();
  }

  @override
  Future<void> setPiece(String seriesId, int slot, bool owned) async {
    final seriesRef = _ref.child(seriesId);
    final snapshot = await seriesRef.get();
    if (!snapshot.exists) return;

    final rawData = snapshot.value;
    if (rawData is! Map) return;

    final data = <String, dynamic>{};
    for (final kv in rawData.entries) {
      data[kv.key.toString()] = kv.value;
    }

    final ownedPieces = (data['ownedPieces'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    final piecesSet = ownedPieces.toSet();

    if (owned) {
      piecesSet.add(slot);
    } else {
      piecesSet.remove(slot);
    }

    await seriesRef.update({
      'ownedPieces': piecesSet.toList()..sort(),
    });
  }

  @override
  Future<List<LighterSeries>> getAllSeries() async {
    final snapshot = await _ref.get();
    if (!snapshot.exists) return [];

    final data = snapshot.value;
    if (data is! Map) return [];

    final seriesList = <LighterSeries>[];
    for (final entry in data.entries) {
      try {
        final value = entry.value;
        if (value is Map) {
          final jsonMap = <String, dynamic>{};
          for (final kv in value.entries) {
            jsonMap[kv.key.toString()] = kv.value;
          }
          final series = LighterSeries.fromJson(jsonMap);
          seriesList.add(series);
        }
      } catch (e) {
        continue;
      }
    }
    return seriesList;
  }
}

