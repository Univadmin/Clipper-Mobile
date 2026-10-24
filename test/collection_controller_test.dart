import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/controllers/collection_controller.dart';
import 'package:iclip/models/lighter_series.dart';
import 'support/fake_collection_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
LighterSeries series(String id, int number) =>
    LighterSeries(id: id, name: 'İstanbul Serisi', seriesNumber: number);

void main() {
  test(
    'Dış istemcinin aynı anahtarla seri numarası değiştirmesi görünür uyarı verir',
    () async {
      final repository = FakeCollectionRepository([series('series-1', 22)]);
      addTearDown(repository.close);
      final controller = LighterCollectionController(repo: repository);
      addTearDown(controller.dispose);
      await flush();
      expect(controller.dataWarning, isNull);
      repository.records['series-1'] = series('series-1', 62);
      repository.publish();
      await flush();
      expect(controller.dataWarning, contains('Eski APK'));
      expect(controller.series.single.seriesNumber, 62);
    },
  );

  test(
    '40 eski kayıttan sonra 120 ekleme ve yeniden açılış hiçbir kaydı ezmez',
    () async {
      final originals = List.generate(
        40,
        (i) => series('series-${i + 1}', i + 22),
      );
      final repository = FakeCollectionRepository(originals);
      addTearDown(repository.close);
      for (var session = 0; session < 3; session++) {
        final controller = LighterCollectionController(repo: repository);
        await flush();
        for (var i = 0; i < 40; i++) {
          expect(
            await controller.upsertSeries(name: 'Yeni $session-$i'),
            isTrue,
          );
        }
        await flush();
        expect(controller.totalSeries, 40 + (session + 1) * 40);
        controller.dispose();
      }
      for (final original in originals) {
        expect(repository.records[original.id], same(original));
      }
      expect(
        repository.records.values.map((s) => s.seriesNumber).toSet().length,
        160,
      );
      expect(
        repository.records.values
            .map((s) => s.seriesNumber)
            .reduce((a, b) => a > b ? a : b),
        181,
      );
    },
  );

  test('Yeniden açılışta ekleme eski series-1 kaydını korur', () async {
    final repository = FakeCollectionRepository([series('series-1', 1)]);
    addTearDown(repository.close);
    for (var i = 0; i < 3; i++) {
      final controller = LighterCollectionController(repo: repository);
      await flush();
      expect(await controller.upsertSeries(name: 'Yeni $i'), isTrue);
      controller.dispose();
    }
    expect(repository.records.length, 4);
    expect(repository.records['series-1']!.name, 'İstanbul Serisi');
    expect(
      repository.records.values.map((s) => s.seriesNumber).toSet().length,
      4,
    );
  });

  test(
    'Çift kaydetme tek yazma yapar; bekleyen işlem dispose sonrasında bildirim yapmaz',
    () async {
      final repository = FakeCollectionRepository()
        ..pendingWrite = Completer<void>();
      addTearDown(repository.close);
      final controller = LighterCollectionController(repo: repository);
      await flush();
      final first = controller.upsertSeries(name: 'Bir');
      expect(controller.isSaving, isTrue);
      expect(await controller.upsertSeries(name: 'İki'), isFalse);
      expect(repository.writeCount, 1);
      controller.dispose();
      repository.pendingWrite!.complete();
      expect(await first, isFalse);
    },
  );

  test(
    'Başarısız yazma yoğun durumunu temizler ve yeniden denemeye izin verir',
    () async {
      final repository = FakeCollectionRepository()..failWrites = true;
      addTearDown(repository.close);
      final controller = LighterCollectionController(repo: repository);
      addTearDown(controller.dispose);
      await flush();
      expect(await controller.upsertSeries(name: 'Test'), isFalse);
      expect(controller.isSaving, isFalse);
      expect(controller.operationError, isNotNull);
      repository.failWrites = false;
      expect(await controller.upsertSeries(name: 'Test'), isTrue);
    },
  );

  test(
    'Stream hatasında eski liste korunur; veri gelince hata temizlenir',
    () async {
      final repository = FakeCollectionRepository([series('old', 2)]);
      addTearDown(repository.close);
      final controller = LighterCollectionController(repo: repository);
      addTearDown(controller.dispose);
      await flush();
      final sorted = controller.series;
      expect(identical(sorted, controller.series), isTrue);
      repository.events.addError(StateError('offline'));
      await flush();
      expect(controller.loadError, isNotNull);
      expect(controller.series.single.id, 'old');
      expect(await controller.removeSeries('old'), isFalse);
      repository.publish();
      await flush();
      expect(controller.loadError, isNull);
      expect(controller.rankedMatches('İSTANBUL').first.score, 1);
    },
  );

  test('Filtre, parça güncelleme ve silme akışı', () async {
    final repository = FakeCollectionRepository([series('one', 1)]);
    addTearDown(repository.close);
    final controller = LighterCollectionController(repo: repository);
    addTearDown(controller.dispose);
    await flush();
    for (var slot = 1; slot <= 4; slot++) {
      expect(await controller.setPiece('one', slot, true), isTrue);
      await flush();
    }
    expect(controller.completedSeries, 1);
    expect(controller.seriesByFilter(SeriesFilter.completed).length, 1);
    expect(await controller.removeSeries('one'), isTrue);
    await flush();
    expect(controller.totalSeries, 0);
  });
}
