# Clipper Mobile — çalışma durumu

## Kararlar
- Tek kullanıcı; `collections/default` ve mevcut kayıt alanları korunur.
- Publice uygun kaynak; Firebase istemci ayarı, uygulama kilidi doğrulama bilgileri ve release anahtarı yalnız Actions Secrets/local ignored config içinde.
- Firebase yönetim erişimi yok. Kullanıcı cihazdaki giriş kilidinin Firebase kurallarının yerine geçmediğini kabul etti. Firebase Authentication veya sunucu kural değişikliği yapılmaz.
- Parola açık metin tutulmaz; PBKDF2-HMAC-SHA256 özetiyle yerel kontrol, cihaz güvenli deposunda oturum işareti.

## Mevcut sürüm ve yayın
`1.0.1+2`. `main` dalında pubspec sürümü artırıldığında Actions imzalı APK, GitHub Release ve downloads listesini üretir. Yayın düzeni `docs/RELEASING.md`, doğrulamalar `docs/RELEASE-VALIDATION-2026-10-25.md` içinde.

## İyileştirmeler
Kimlik çakışması ve parça güncellemesi düzeltmeleri; controller ayrımı, lazy listeler, arama/form taslağı korunması, hata/yeniden deneme, kamera lifecycle ve izin temizliği. Önceki kayıt: `docs/IMPROVEMENTS-2026-10-24.md`.

## Sonraki adım
Android cihazda gerçek kamera/OCR ve mevcut Firebase kurallarıyla bağlantı doğrulanmalı. Firebase sunucu koruması için proje sahibinin yetkisi gerekir. İmzalama anahtarını güncellemelerde değiştirmeyin. iOS config sağlanmadı; iOS yayını yok.
