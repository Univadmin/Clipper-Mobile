import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/main.dart' show ScanResult;
import 'package:iclip/repositories/firebase_collection_repository.dart';

void main() {
  final raw = <String, Object?>{
    'id': 'series-1',
    'name': 'Test',
    'seriesNumber': 1,
    'ownedPieces': <int>[],
    'extra': 'preserved',
  };
  test(
    'Transaction tekrarında en son parça durumu korunur, şema aynı kalır',
    () {
      final firstClient = changePiece(raw, 1, true);
      final retriedSecondClient = changePiece(firstClient, 2, true);
      expect(retriedSecondClient['ownedPieces'], [1, 2]);
      expect(retriedSecondClient['extra'], 'preserved');
      expect(retriedSecondClient.keys.toSet(), raw.keys.toSet());
      expect(changePiece(retriedSecondClient, 1, false)['ownedPieces'], [2]);
      expect(raw['ownedPieces'], isEmpty);
    },
  );
  test('Silinmiş seri ve geçersiz slot değiştirilemez', () {
    expect(() => changePiece(null, 1, true), throwsFormatException);
    expect(() => changePiece(raw, 5, true), throwsArgumentError);
  });
  test(
    'Firebase anahtarı kaynak kimliktir; bozuk kayıt sessizce kaybolmaz',
    () {
      final decoded = decodeCollection({'key': raw});
      expect(decoded.single.id, 'key');
      expect(() => decoded.single.ownedPieces.add(1), throwsUnsupportedError);
      expect(
        () => decodeCollection({
          'broken': {'name': 'Test'},
        }),
        throwsFormatException,
      );
    },
  );
  test('OCR Türkçe seri adını ve geçerli parçayı ayrıştırır', () {
    final parsed = ScanResult.tryParse('İstanbul - 3 / 4');
    expect(parsed!.seriesName, 'İstanbul');
    expect(parsed.slot, 3);
    expect(ScanResult.tryParse('Test 5/4'), isNull);
    expect(ScanResult.tryParse('yalnız metin'), isNull);
  });
}
