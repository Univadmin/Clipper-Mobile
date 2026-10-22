# Clipper Mobile

iClip çakmak koleksiyon uygulaması. Seri oluşturma/düzenleme/silme, dört parçalı serilerde sahip olunan parçaları işaretleme, tam/eksik seri filtreleri ve istatistikler sunar. Kamera ve ML Kit OCR ile seri adı/parça numarası okur; Firebase Realtime Database ile verileri tutar.

- Sürüm: `1.0.0+1` (`pubspec.yaml` ana kaynaktır).
- Teknoloji: Flutter / Dart; bağımlılık kilidi `pubspec.lock`.
- Ana kaynak ve sürüm geçmişi: https://github.com/Univadmin/Clipper-Mobile
- Mac çalışma kopyası: `~/Projects/Clipper-Mobile`. Eski LocalProjects klasörü korunmuş ilk kaynak arşividir; geliştirmeye bu kopyada devam edin.

## Geliştirme

```sh
git status
git pull --ff-only
flutter pub get
flutter analyze
flutter test
```

Platform SDK, cihaz/simülatör, yerel ayarlar ve imzalama hazır olduktan sonra `flutter run` kullanın. İlk aktarım bir üretim/mağaza yayını değildir. Paket kimlikleri ve mevcut sürüm numaraları korunmuştur; repository başlığı uygulama kimliğini değiştirmez.

## Proje haritası

`lib/main.dart`: UI, koleksiyon controller, OCR ve eşleştirme; büyük dosyada yalnız ilgili sınıfı oku. `lib/models/lighter_series.dart`: seri modeli. `lib/repositories/collection_repository.dart`: sözleşme. `firebase_collection_repository.dart`: Firebase uygulaması.

## Yerel ayarlar ve bilinen sınırlar

Firebase varsayılan collections/default yolu kullanılıyor; kullanıcı ayrımı ve DB güvenlik kuralları ayrıca incelenmeli. Gerçek koleksiyon üzerinde yazma/silme testi yapma. google-services.json ve Apple Firebase config yerelde sağlanmalı. Kamera/ML Kit gerçek cihaz doğrulaması gerektirir. Release şu an debug signing kullanıyor. Mevcut widget testleri Firebase/plugin izolasyonu olmadan çalışmayabilir.

Build/cache, cihaz SDK yolları, trafik kayıtları, şifreler, Firebase yerel config ve imzalama dosyaları Git dışında tutulur. Gerçek sırları dart-define ile derlemek de binary içinde gizli tutmaz; üretim dağıtımında kullanıcı girişi ve uygun güvenli saklama tasarlanmalı.

## Sürüm yönetimi

Kaynak değişiklikleri konu branch’inde geliştirilir; ilgili kontrollerden sonra diff incelenir, commit ve normal push yapılır. `pubspec.yaml` sürümü bilinçli artırılır. Doğrulanmış yayınlar için `v<version>+<build>` tag ve GitHub Releases kullanılabilir; ilk aktarımda mevcut sürüm doğrulanmış release olarak işaretlenmedi. APK/IPA gibi yayın çıktıları gerekiyorsa GitHub Releases’e, secret içermeden eklenir. Yerel kaynak kopyası geliştirme için gereklidir; GitHub kalıcı ortak kaynaktır.

Kontrol sonuçları: [docs/VALIDATION.md](docs/VALIDATION.md). Kısa çalışma durumu: [PROJECT.md](PROJECT.md).
