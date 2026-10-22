import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iclip/main.dart';

void main() {
  testWidgets('Koleksiyon sekmesi varsayılan olarak açılır',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LighterCollectionApp());

    expect(find.text('Koleksiyon'), findsWidgets);
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('Ekle / Düzenle formu doğrulama mesajı gösterir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LighterCollectionApp());

    await tester.tap(find.text('Ekle / Düzenle'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seriyi Kaydet'));
    await tester.pump();

    expect(find.text('Lütfen bir seri adı girin'), findsOneWidget);
  });
}



