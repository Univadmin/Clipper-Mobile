import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/services/ocr.dart';

void main() {
  test('OCR marka, satır, Türkçe karakter ve eğik çizgi çeşitlerini işler', () {
    final result = ScanResult.tryParse(
      'CLIPPER\nİstanbul Geceleri\nMade in Spain\n3 ／ 4',
    );
    expect(result!.seriesName, 'İstanbul Geceleri');
    expect(result.slot, 3);
    expect(ScanResult.tryParse('Urban Art I/4')!.slot, 1);
    expect(ScanResult.tryParse('Urban Art 2 of 4')!.slot, 2);
    expect(ScanResult.tryParse('Test 12/4'), isNull);
    expect(ScanResult.tryParse('CLIPPER\n1/4'), isNull);
  });
  test(
    'Eşleştirme Türkçe ve aksansız adları eşit görür, kısmi adı kesin saymaz',
    () {
      double score(String a, String b) =>
          seriesNameScore(normalizeSeriesName(a), normalizeSeriesName(b));
      expect(score('CLIPPER İstanbul Serisi', 'istanbul'), 1);
      expect(score('Urban', 'Urban Art'), lessThan(0.92));
      expect(score('Urban Art 2', 'Urban Art 3'), lessThan(0.35));
      expect(score('Urbam Art', 'Urban Art'), greaterThan(0.6));
      expect(score('Ocean Fish', 'Space Rocket'), lessThan(0.35));
      expect(score('', 'Urban Art'), 0);
    },
  );
}
