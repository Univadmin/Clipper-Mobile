# Clipper Mobile

Türkçe çalış. Ana kaynak private GitHub repository: Univadmin/Clipper-Mobile.

- Önce `git status`; temiz ağaçta `git pull --ff-only`. Ayrışmada dur; hard reset, force push, rebase veya otomatik çatışma çözümü yapma.
- Önce PROJECT.md ve gereken README bölümü; yalnız görevle ilgili dosya/sınıfları oku. Tüm platformları veya üretilmiş dosyaları tarama.
- Proje haritası: `lib/main.dart`: UI, koleksiyon controller, OCR ve eşleştirme; büyük dosyada yalnız ilgili sınıfı oku. `lib/models/lighter_series.dart`: seri modeli. `lib/repositories/collection_repository.dart`: sözleşme. `firebase_collection_repository.dart`: Firebase uygulaması.
- Ürün: iClip çakmak koleksiyon uygulaması. Seri oluşturma/düzenleme/silme, dört parçalı serilerde sahip olunan parçaları işaretleme, tam/eksik seri filtreleri ve istatistikler sunar. Kamera ve ML Kit OCR ile seri adı/parça numarası okur; Firebase Realtime Database ile verileri tutar.
- Görev bitince kısa karar/sonraki adımı PROJECT.md’ye yaz. Sohbet dökümü ekleme. Basit işte ayrı agent veya skill çoğaltma.
- Gerçek API/Firebase/kapı/alarm işlemlerini doğrulama amacıyla başlatma. Mock/fake kullan; canlı işlem için açık yetki gerekir.
- Secret, kişisel/müşteri verisi, trafik kayıtları, yerel config, signing ve build/cache Git’e girmez; loglarda göstermeden kontrol et.
- Bağımlılık veya ürün sürümünü görev gerektirmedikçe değiştirme. Yeni özellikleri konu branch’inde geliştir.
- İlgili `flutter analyze` ve testleri çalıştır; ilk aktarımın bilinen sorunları docs/VALIDATION.md’de. Test başarısızlığını gizleme; alakasız hataları düzeltmek için kapsamı büyütme.
- Commit/push öncesi `git diff --check`, `git diff --stat`, değişen diff ve secret kontrolü; yalnız görev dosyalarını ekle. Güvenli tamamlanan değişiklikleri normal commit/push ile GitHub’a aktar.
- Dikkat: Firebase varsayılan collections/default yolu kullanılıyor; kullanıcı ayrımı ve DB güvenlik kuralları ayrıca incelenmeli. Gerçek koleksiyon üzerinde yazma/silme testi yapma. google-services.json ve Apple Firebase config yerelde sağlanmalı. Kamera/ML Kit gerçek cihaz doğrulaması gerektirir. Release şu an debug signing kullanıyor. Mevcut widget testleri Firebase/plugin izolasyonu olmadan çalışmayabilir.
