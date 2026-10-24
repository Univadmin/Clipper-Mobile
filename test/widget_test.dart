import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/main.dart';
import 'package:iclip/models/lighter_series.dart';
import 'support/fake_collection_repository.dart';

void main() {
  testWidgets('Koleksiyon sekmesi varsayılan olarak açılır', (tester) async {
    final repository = FakeCollectionRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Koleksiyon'), findsWidgets);
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('Form boş adı reddeder ve başarılı eklemeyi listeler', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekle / Düzenle').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Seriyi Kaydet'));
    await tester.tap(find.text('Seriyi Kaydet'));
    await tester.pump();
    expect(find.text('Lütfen bir seri adı girin'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Yeni Seri');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Seriyi Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seriyi Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.records.values.single.name, 'Yeni Seri');
    expect(find.text('Seri başarıyla eklendi'), findsOneWidget);
  });

  testWidgets('Yazma hatasında form korunur ve başarı mesajı gösterilmez', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()..failWrites = true;
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekle / Düzenle').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Korunan Seri');
    await tester.ensureVisible(find.text('Seriyi Kaydet'));
    await tester.tap(find.text('Seriyi Kaydet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Değişiklik kaydedilemedi'), findsOneWidget);
    expect(find.text('Seri başarıyla eklendi'), findsNothing);
    expect(find.text('Korunan Seri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Büyük koleksiyon görünür satırları oluşturur ve arama çalışır', (
    tester,
  ) async {
    final repository = FakeCollectionRepository(
      List.generate(
        1000,
        (i) => LighterSeries(
          id: 's$i',
          name: 'Koleksiyon $i',
          seriesNumber: i + 1,
        ),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Koleksiyon 999'), findsNothing);
    expect(find.byType(Card).evaluate().length, lessThan(30));
    await tester.enterText(find.byType(SearchBar), 'Koleksiyon 999');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Card, 'Koleksiyon 999'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yükleme hatası görünür ve yeniden deneme listeyi kurtarır', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    repository.events.addError(StateError('permission denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koleksiyon güncellenemedi'), findsOneWidget);
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koleksiyon güncellenemedi'), findsNothing);
  });
  testWidgets('Dar ekranda sekmeler form taslağını ve aramayı korur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCollectionRepository([
      LighterSeries(
        id: 'one',
        name: 'Çok uzun isimli İstanbul koleksiyon serisi',
        seriesNumber: 1,
      ),
    ]);
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'İstanbul');
    await tester.tap(find.text('Ekle / Düzenle').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Taslak');
    await tester.tap(find.text('Koleksiyon').last);
    await tester.pumpAndSettle();
    expect(find.text('İstanbul'), findsOneWidget);
    await tester.tap(find.text('Ekle / Düzenle').last);
    await tester.pumpAndSettle();
    expect(find.text('Taslak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Düzenleme diyaloğu kapanırken ve sonrasında hata oluşmaz', (
    tester,
  ) async {
    final repository = FakeCollectionRepository([
      LighterSeries(id: 'one', name: 'Eski', seriesNumber: 1),
    ]);
    addTearDown(repository.close);
    await tester.pumpWidget(LighterCollectionApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekle / Düzenle').last);
    await tester.pumpAndSettle();
    final edit = find.byTooltip('Seriyi düzenle');
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'Yeni',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.records['one']!.name, 'Yeni');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
