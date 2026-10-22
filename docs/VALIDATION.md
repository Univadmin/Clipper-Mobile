# İlk aktarım doğrulaması

Tarih: 23 Ekim 2026. Ortam: macOS arm64, Flutter 3.32.1, Dart 3.8.1. Flutter SDK otomatik yükseltilmedi.

- `flutter pub get`: başarılı; pubspec.yaml ve pubspec.lock kaynakla aynı kaldı.
- `flutter analyze --no-pub`: exit 1. 6 deprecated API info; error/warning yok.
- `flutter test --no-pub`: exit 1. İki widget testi core/no-app hatasıyla başarısız: Firebase initialize edilmemiş. Fake repository enjeksiyonu veya Firebase mock gerekir.
- Gitleaks 8.30.1: ilk gönderilecek dosyalarda bulgu yok. İndirilen scanner checksum doğrulandı. Ek literal incelemesinde settings_service.dart içindeki password ayar anahtarı gerçek sır değil.
- Ürün sürümü ve application/bundle kimlikleri korunmuştur.
- APK/IPA/mağaza yayını ve gerçek cihaz doğrulaması yapılmadı. Gerçek API/kapı/Firebase üzerinde operasyon testi yapılmadı. Test komutları mevcut test kodunu kullandı.

## Aktarım kapsamı

Kaynak uygulama klasöründeki dosyalar temel alındı. build/cache, IDE yerel dosyaları, signing, local.properties, key.properties, Firebase yerel config ve trafik kayıtları (.har) Git dışında. Kaynak LocalProjects klasöründe hiçbir dosya değiştirilmedi veya silinmedi. MGS üst klasöründeki dist ve bağımsız temptest bu uygulama repository’lerine dahil edilmedi.

Rosslare lib/constants.dart içindeki sabit kimlik bilgileri gönderim öncesinde boş varsayımlı String.fromEnvironment ile değiştirildi. Kullanıcı, parolayı UI ayarlarından sağlayabilir; gerçek sırları repository’ye eklemeyin.

Bu aktarım mevcut kaynak kodunun güvenli sürümleme başlangıcıdır; başarısız kontroller başarılı gösterilmez. Testlerin düzeltilmesi sonraki geliştirme işidir.
