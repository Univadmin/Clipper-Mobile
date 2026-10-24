# Clipper iyileştirme ve doğrulama kaydı

Tarih: 24 Ekim 2026. Flutter 3.32.1, Dart 3.8.1, macOS arm64. Ürün sürümü 1.0.0+1 ve paket kimlikleri korunmuştur.

## Korunan davranış

Kullanıcı tek kişi. Firebase Realtime Database `collections/default` yolu, mevcut seri kimlikleri ve `id/name/seriesNumber/ownedPieces` kayıt alanları aynıdır. Göç, kullanıcı hesabı veya sunucu kural değişikliği yoktur. Eski kayıtlar yerinde kalır; yalnız yeni kayıtlar rastgele kimlik kullanır.

## Düzeltmeler

- Oturumda sıfırlanan seri sayacı yerine 128 bit güvenli rastgele kimlik; oluşturma transaction'ı var olan kimliği ezmez.
- Parça değiştirme transaction ile güncel sunucu değerine uygulanır. Güncelleme silinmiş seriyi yeniden oluşturmaz. Mevcut liste biçimi korunur; ilave alanlar silinmez.
- Controller UI dosyasından ayrıldı. Sıralama, toplamlar ve normalize edilmiş OCR adları yalnız yeni veri geldiğinde hesaplanır. En iyi OCR eşleşmesi tüm sonuçları sıralamadan tek geçişte bulunur.
- Koleksiyon ve yönetim listeleri yalnız görünür satırları oluşturur. 1000 kayıtlı widget testinde ilk görünümde 30'dan az Card oluşturuldu; aramayla son kayıt bulunabildi. Bu bir FPS/bellek benchmark'ı değildir.
- Sekmeler arama, kaydırma ve form taslağını korur. Dar ekranda üst çubuktaki yinelenen istatistikler gizlenir; koleksiyon filtre/istatistikleri kalır.
- Bekleyen yazmalarda ilerleme ve seri bazlı işlem kilitleri; çift ekleme engeli. Başarı mesajı yalnız onaylanan işlemden sonra görünür; hatada form içeriği korunur.
- Başlangıç ve stream hataları için anlaşılır ekran/uyarı ve yeniden deneme. Bozuk kayıtlar sessizce atılmaz; hata gösterilir, daha önce yüklenmiş liste korunur.
- Kamerada erken çıkış, uygulamanın arka plana geçmesi ve gecikmiş initialize/OCR dönüşlerinde kaynak/state yönetimi düzeltildi. OCR motoru yalnız kamera ekranında oluşturulur. Düzenleme alanının controller yaşam döngüsü sorunu kaldırıldı.
- iOS kamera açıklaması ve görünen ürün adı düzeltildi. Android ana manifestine internet/kamera izni eklendi; yalnız fotoğraf/OCR için gerekmeyen mikrofon ve paylaşılan depolama izinleri kaldırıldı.
- Eski yerel Clipper uygulamasındaki Android Firebase istemci config dosyası kullanıcı talebiyle paketlenip sürümlendi. Apple config aynı kaynakta bulunamadı; uydurulmadı.

## Doğrulama

- `flutter analyze --no-pub`: başarılı; 0 bulgu.
- `flutter test --no-pub --reporter expanded`: 16 test başarılı.
- `flutter build apk --debug --no-pub`: başarılı. Son manifest temizliğinden sonra tekrar başarılı. APK izin dökümünde mikrofon ve paylaşılan depolama izinleri bulunmadığı doğrulandı.
- `git diff --check`: başarılı.
- Regresyonlar: eski series-1 kaydını koruyarak yeniden açılışta ekleme, çift kaydetme, başarısız yazma/yeniden deneme, dispose sırasında bekleyen yazma, stream hatası, CRUD/filtre, transaction dönüşümünde en son parçaları/alanları koruma, bozuk veri, OCR ayrıştırma, 1000 kayıtlı arama/lazy liste, dar ekran ve sekme taslakları, düzenleme diyaloğunun kapanması.
- Gitleaks 8.30.1 kaynak payload taraması: tek bulgu, kullanıcı tarafından paketlenmesi istenen google-services.json içindeki Firebase istemci API anahtarı (gcp-api-key). Servis hesabı/private key eklenmedi; tarama sıfır bulgu olarak sunulmaz. Firebase istemci anahtarının rolü ve API kısıtları: https://firebase.google.com/docs/projects/api-keys . Gerçek sunucu/API kısıtları bu görevde denetlenmedi.

## Sınırlar

Canlı Firebase üzerinde okuma/yazma/silme testi yapılmadı; transaction callback dönüşümleri offline test edildi, gerçek SDK/sunucu yarışları Emulator entegrasyon testiyle doğrulanmadı. Sunucu kuralları değiştirilmedi. Gerçek cihaz kamera/OCR ve lifecycle davranışı ayrıca doğrulanmalı. Android debug APK bir mağaza yayını değildir. Release imzalama anahtarı sağlanmadığı için mevcut debug signing ayarı korunmuştur. iOS Firebase Apple config bulunmadığı ve iOS build çalıştırılmadığı için iOS hazır kabul edilmez. Bağımlılık veya ürün sürümü yükseltilmedi.

## 25 Ekim 2026 yayın güncellemesi

Bu yerel kontrolün ardından public kaynak hazırlığı için Firebase Android config Git dışında/Actions Secrets içine alındı. Release artık özel kalıcı anahtarla imzalanır. Cihazdaki giriş kilidi ve sürümlü APK dağıtımı için güncel kayıt `docs/RELEASE-VALIDATION-2026-10-25.md` içindedir.
