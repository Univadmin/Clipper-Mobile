import 'package:firebase_database/firebase_database.dart';
import '../models/lighter_series.dart';
import 'collection_repository.dart';

class FirebaseCollectionRepository implements CollectionRepository {
  FirebaseCollectionRepository({String? userId})
    : _ref = FirebaseDatabase.instance.ref(
        'collections/${userId ?? 'default'}',
      );

  final DatabaseReference _ref;

  @override
  Stream<List<LighterSeries>> watchSeries() =>
      _ref.onValue.map((event) => decodeCollection(event.snapshot.value));

  @override
  Future<void> addSeries(LighterSeries series) async {
    final result = await _ref.child(series.id).runTransaction((current) {
      if (current != null) return Transaction.abort();
      return Transaction.success(series.toJson());
    }, applyLocally: false);
    if (!result.committed) throw StateError('Seri kimliği zaten kullanılıyor');
  }

  @override
  Future<void> updateSeries(LighterSeries series) async {
    final result = await _ref.child(series.id).runTransaction((current) {
      // Null can be a cold cache. Returning null permits a server retry,
      // and never recreates a record deleted by another client.
      if (current == null) return Transaction.success(null);
      if (current is! Map) return Transaction.abort();
      return Transaction.success({...current, ...series.toJson()});
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('Seri güncellenemedi veya silinmiş');
    }
  }

  @override
  Future<void> deleteSeries(String id) => _ref.child(id).remove();

  @override
  Future<void> setPiece(String seriesId, int slot, bool owned) async {
    if (slot < 1 || slot > 4) throw ArgumentError.value(slot);
    final result = await _ref.child(seriesId).runTransaction((current) {
      if (current == null) return Transaction.success(null);
      return Transaction.success(changePiece(current, slot, owned));
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('Seri güncellenemedi veya silinmiş');
    }
  }

  @override
  Future<List<LighterSeries>> getAllSeries() async =>
      decodeCollection((await _ref.get()).value);
}

// Pure transformations are also used by offline regression tests.
List<LighterSeries> decodeCollection(Object? value) {
  if (value == null) return [];
  if (value is! Map) throw const FormatException('Geçersiz koleksiyon');
  return value.entries.map((entry) {
    final raw = entry.value;
    if (raw is! Map) throw const FormatException('Geçersiz seri');
    return LighterSeries.fromJson({
      for (final field in raw.entries) field.key.toString(): field.value,
      'id': entry.key.toString(),
    });
  }).toList();
}

Map<String, Object?> changePiece(Object? current, int slot, bool owned) {
  if (slot < 1 || slot > 4) throw ArgumentError.value(slot);
  if (current is! Map) throw const FormatException('Geçersiz seri');
  final series = LighterSeries.fromJson({
    for (final entry in current.entries) entry.key.toString(): entry.value,
  });
  final pieces = {...series.ownedPieces};
  if (owned) {
    pieces.add(slot);
  } else {
    pieces.remove(slot);
  }
  return {
    for (final entry in current.entries) entry.key.toString(): entry.value,
    'ownedPieces': pieces.toList()..sort(),
  };
}
