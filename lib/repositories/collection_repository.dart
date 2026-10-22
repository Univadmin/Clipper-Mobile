import 'dart:async';
import '../models/lighter_series.dart';

abstract class CollectionRepository {
  Stream<List<LighterSeries>> watchSeries();
  Future<void> addSeries(LighterSeries series);
  Future<void> updateSeries(LighterSeries series);
  Future<void> deleteSeries(String id);
  Future<void> setPiece(String seriesId, int slot, bool owned);
  Future<List<LighterSeries>> getAllSeries();
}

