# Yayın doğrulaması — 25 Ekim 2026

Sürüm: `1.0.1+2`. Flutter 3.32.1 / Dart 3.8.1. Önceki sağlık raporu düzeltmeleri bu yayına dahildir.

- `flutter analyze --no-pub`: 0 bulgu.
- `flutter test --no-pub`: 20 test başarılı. Yeni testler girişten önce koleksiyonun açılmamasını, giriş/çıkışı, hatalı girişi, eksik derleme yapılandırmasında kilidin kapalı kalmasını ve Python/Dart PBKDF2 uyumunu doğrular.
- Python yayın testleri: başarılı; sürüm sırası, İstanbul tarihi, yalnız yayımlanmış APK’ların listelenmesi, taslak ve ön sürümlerin dışlanması.
- Kalıcı release imzalama anahtarı oluşturuldu; altı özel derleme girdisi yalnız kullanıcı onaylı Actions Secrets ve Git dışındaki yerel yedekte tutulur.
- Publice gönderilecek dal `origin/main` üzerinden oluşturuldu. Firebase istemci JSON’unu içeren eski yerel commit bu dalın atası değildir; geçmiş yeniden yazılmadı, eski dal korunur.
- Gerçek Firebase verisi üzerinde okuma/yazma/silme testi, sunucu kural değişikliği ve gerçek cihaz kamera/OCR testi yapılmadı. Uygulama kilidi sunucu erişim güvenliği değildir.

- İmzalı `flutter build apk --release --no-pub --dart-define-from-file=.release/login.json`: başarılı; yaklaşık 41.7 MB.
- `apksigner verify`: başarılı; özel iClip Release sertifikası, debug imzası değil.
- APK paket/sürüm: `com.iclip`, versionName `1.0.1`, versionCode `2`. Mikrofon ve ortak depolama izinleri yok.
- APK uygulama snapshot'larında düz metin giriş parolası bulunmadı.
- Public kaynak dosyalarında özel derleme girdileri yok; Gitleaks 0 bulgu.
- R8 yalnız Latin dışındaki isteğe bağlı OCR sınıfları için dar kapsamlı dontwarn kurallarıyla düzeltildi; optimizasyon açık.

GitHub Actions sonucu ilgili workflow run ve GitHub Release sayfasından izlenir.
