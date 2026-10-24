# Clipper Mobile — iClip

Çakmak koleksiyonu takibi: seri ekleme/düzenleme/silme, dört parçalı setlerin tamamlanma durumu, arama, filtre ve kamera/OCR.

## Downloads

**[Son sürüm APK’yı indir](https://github.com/Univadmin/Clipper-Mobile/releases/latest/download/Clipper.apk)**

**[Tüm sürümler: sürüm / tarih / indirme bağlantısı](downloads/README.md)**

APK’yı kurup uygulama giriş bilgileriyle açın. Firebase bağlantı ayarları derlenmiş APK’da hazırdır. Android sürümü: `pubspec.yaml`.

## Geliştirme ve yayın

```sh
flutter pub get --enforce-lockfile
python3 scripts/check.py
```

Public kaynak kodunda Firebase istemci config, giriş bilgileri ve imzalama anahtarı bulunmaz. Bunlar Actions Secrets üzerinden yalnız release derlemesinde sağlanır. Secrets olmadan derlenen uygulama kilidi kapalı kalır; varsayılan kullanıcı/parola yoktur. Testler fake repository kullanır.

Yeni güncellemede `pubspec.yaml` sürümünü ve build numarasını artırıp `main` dalına gönderin. Örneğin `1.0.2+3` sonrasında `1.0.3+4`. Actions analiz/testlerden sonra imzalı APK’yı GitHub Releases’e yükler ve `downloads` tablosunu otomatik günceller. Eski sürüm dosyaları korunur. Aynı sürümün APK’sı değiştirilmez.

Kurulum ve yayın: [Yayın rehberi](docs/RELEASING.md). Değişiklikler: [Sürüm notları](CHANGELOG.md). Geliştirme: [Katkı rehberi](CONTRIBUTING.md).

## Yapı

- `lib/main.dart`: UI.
- `lib/screens/camera_scanner_page.dart`: kamera ve cihaz OCR işlemi.
- `lib/services/ocr.dart`: OCR metin ayrıştırma ve seri eşleştirme.
- `lib/widgets/scan_review_sheet.dart`: tarama sonucunu düzenleme.
- `lib/controllers/collection_controller.dart`: koleksiyon durumu ve eşleştirme.
- `lib/auth/`: cihazdaki uygulama kilidi ve oturum saklama.
- `lib/models/lighter_series.dart`: seri modeli.
- `lib/repositories/`: Firebase veri erişimi.

Tek kullanıcı ve mevcut `collections/default` kayıt yapısı korunur. Uygulama kilidi Firebase Authentication değildir; veritabanı sunucu erişim kuralları bu projedeki yayın akışı tarafından değiştirilmez. APK içindeki istemci ayarları ve doğrulama bilgileri analiz edilebilir; Secrets public kaynak kodundan gizler, APK’yı gizli kasa yapmaz. iOS Firebase config sağlanmadığından iOS dağıtımı hazırlanmadı.
