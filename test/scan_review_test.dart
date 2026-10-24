import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/services/ocr.dart';
import 'package:iclip/widgets/scan_review_sheet.dart';

void main() {
  testWidgets(
    'Tarama sonucu düzenlenir; bekleyen kayıtta çift gönderim engellenir',
    (tester) async {
      var calls = 0;
      String? savedName;
      int? savedSlot;
      final pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanReviewSheet(
              result: const ScanResult(seriesName: 'Yanlış', slot: 1),
              onSave: (name, slot) {
                calls++;
                savedName = name;
                savedSlot = slot;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '  Doğru seri  ');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3/4').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koleksiyona ekle'));
      await tester.pump();
      expect(find.text('Kaydediliyor…'), findsOneWidget);
      expect(calls, 1);
      expect(savedName, 'Doğru seri');
      expect(savedSlot, 3);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Koleksiyona ekle'), findsOneWidget);
      expect(find.text('Doğru seri'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Koleksiyona ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Seri adını gir'), findsOneWidget);
      expect(calls, 1);
    },
  );
}
