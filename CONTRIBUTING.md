# Geliştirme

Flutter 3.32.1 ve Java 17 kullanılır. `flutter pub get --enforce-lockfile` sonrasında `python3 scripts/check.py` analiz ve testleri çalıştırır. Testler fake repository kullanır, canlı koleksiyonu değiştirmez.

İlgili modülü değiştirip o modülün testini çalıştırın; yayın öncesinde tüm kontrolleri çalıştırın. OCR kuralları `lib/services/ocr.dart`, durum ve yazma işlemleri `lib/controllers/collection_controller.dart`, veri erişimi `lib/repositories/`, ekranlar `lib/main.dart`, kamera `lib/screens/camera_scanner_page.dart` içindedir. Firebase kayıt şeması ve koleksiyon yolu korunur.

Güncelleme için pubspec sürüm/build numarasını artırın. Main dalına gönderim APK’yı üretir; Gradle ve Flutter önbellekleri yeniden derlemeyi hızlandırır. Yayın adımları ve gerekli Secrets için [yayın rehberi](docs/RELEASING.md). APK, özel ayar, anahtar ve derleme çıktısı kaynak koduna eklenmez.
