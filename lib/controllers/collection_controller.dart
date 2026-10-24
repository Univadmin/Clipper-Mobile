import '../services/ocr.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/lighter_series.dart';
import '../repositories/collection_repository.dart';

enum SeriesFilter { completed, inProgress }

class LighterCollectionController extends ChangeNotifier {
  LighterCollectionController({required CollectionRepository repo})
    : repository = repo {
    _listen();
  }

  final CollectionRepository repository;
  StreamSubscription<List<LighterSeries>>? _subscription;
  UnmodifiableListView<LighterSeries> _series = UnmodifiableListView([]);
  final Set<String> _pending = {};
  final Map<String, String> _normalizedNames = {};
  bool _disposed = false;
  bool _isLoading = true;
  String? loadError;
  String? dataWarning;
  String? operationError;
  int errorVersion = 0;
  int _completedSeries = 0;
  int _nextNumber = 1;
  int _generation = 0;

  bool get isLoading => _isLoading;
  bool get isSaving => _pending.isNotEmpty;
  bool isBusy(String id) => _pending.contains(id);
  UnmodifiableListView<LighterSeries> get series => _series;
  int get totalSeries => _series.length;
  int get completedSeries => _completedSeries;
  int get inProgressSeries => totalSeries - completedSeries;
  int get nextSeriesNumber => _nextNumber;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    final generation = ++_generation;
    try {
      _subscription = repository.watchSeries().listen(
        (items) {
          if (_disposed || generation != _generation) return;
          final ordered = [...items]
            ..sort((a, b) {
              final number = a.seriesNumber.compareTo(b.seriesNumber);
              return number == 0 ? a.id.compareTo(b.id) : number;
            });
          final previousNumbers = {
            for (final s in _series) s.id: s.seriesNumber,
          };
          if (ordered.any(
            (s) =>
                previousNumbers.containsKey(s.id) &&
                previousNumbers[s.id] != s.seriesNumber,
          )) {
            dataWarning =
                'Başka bir kurulum mevcut kayıtların seri numarasını değiştirdi. Eski APK’ları kapatıp tüm cihazları son sürüme güncelleyin.';
          }
          _series = UnmodifiableListView(ordered);
          _normalizedNames
            ..clear()
            ..addEntries(
              ordered.map((s) => MapEntry(s.id, normalizeSeriesName(s.name))),
            );
          _completedSeries = ordered.where((s) => s.isComplete).length;
          final fromData = ordered.isEmpty
              ? 1
              : ordered.map((s) => s.seriesNumber).reduce(max) + 1;
          _nextNumber = max(_nextNumber, fromData);
          _isLoading = false;
          loadError = null;
          _notify();
        },
        onError: (Object error) {
          if (_disposed || generation != _generation) return;
          _loadFailed();
        },
      );
    } catch (_) {
      _loadFailed();
    }
  }

  void _loadFailed() {
    _isLoading = false;
    loadError =
        'Koleksiyon güncellenemedi. Bağlantıyı kontrol edip yeniden deneyin. Mevcut liste güncel olmayabilir.';
    _notify();
  }

  Future<void> retry() async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    loadError = null;
    _generation++;
    _notify();
    // Do not block a retry on platform-channel teardown. Stale events are
    // ignored by the generation token while the old listener is removed.
    unawaited(_subscription?.cancel());
    if (!_disposed) _listen();
  }

  List<LighterSeries> seriesByFilter(SeriesFilter filter) => _series
      .where(
        (s) => filter == SeriesFilter.completed ? s.isComplete : !s.isComplete,
      )
      .toList();

  LighterSeries? getById(String id) {
    for (final series in _series) {
      if (series.id == id) return series;
    }
    return null;
  }

  List<SeriesMatch> rankedMatches(String rawText) {
    final query = normalizeSeriesName(rawText);
    if (query.isEmpty) return const [];
    final results = <SeriesMatch>[];
    for (final series in _series) {
      final score = seriesNameScore(query, _normalizedNames[series.id]!);
      if (score > 0) results.add(SeriesMatch(series: series, score: score));
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  LighterSeries? findBestMatch(String rawText, {double minScore = 0.92}) {
    final query = normalizeSeriesName(rawText);
    if (query.isEmpty) return null;
    LighterSeries? best;
    var bestScore = 0.0;
    for (final series in _series) {
      final score = seriesNameScore(query, _normalizedNames[series.id]!);
      if (score > bestScore) {
        bestScore = score;
        best = series;
      }
    }
    return bestScore >= minScore ? best : null;
  }

  Future<bool> _write(String key, Future<void> Function() action) async {
    if (_disposed || _pending.contains(key)) return false;
    if (_isLoading || loadError != null) {
      operationError = 'Önce koleksiyon bağlantısını yeniden kurun.';
      errorVersion++;
      _notify();
      return false;
    }
    _pending.add(key);
    operationError = null;
    _notify();
    try {
      await action();
      return !_disposed;
    } catch (_) {
      operationError =
          'Değişiklik kaydedilemedi. Bağlantıyı kontrol edip tekrar deneyin.';
      errorVersion++;
      return false;
    } finally {
      _pending.remove(key);
      _notify();
    }
  }

  Future<bool> upsertSeries({
    String? id,
    required String name,
    Set<int>? ownedPieces,
  }) => _write(id ?? '_add', () async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Seri adı boş olamaz');
    final pieces = (ownedPieces ?? <int>{})
        .where((slot) => slot >= 1 && slot <= 4)
        .toSet();
    if (id == null) {
      final number = _nextNumber++;
      await repository.addSeries(
        LighterSeries(
          id: _newId(),
          name: trimmed,
          seriesNumber: number,
          ownedPieces: pieces,
        ),
      );
    } else {
      final existing = getById(id);
      if (existing == null) throw StateError('Seri artık yok');
      await repository.updateSeries(
        existing.copyWith(name: trimmed, ownedPieces: pieces),
      );
    }
  });

  Future<bool> setPiece(String id, int slot, bool owned) =>
      _write(id, () async {
        if (slot < 1 || slot > 4) throw ArgumentError.value(slot);
        await repository.setPiece(id, slot, owned);
      });

  Future<bool> removeSeries(String id) =>
      _write(id, () => repository.deleteSeries(id));

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  static final Random _random = Random.secure();
  static String _newId() =>
      'series-${List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class SeriesMatch {
  const SeriesMatch({required this.series, required this.score});
  final LighterSeries series;
  final double score;
}
