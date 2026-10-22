# Clipper Mobile — çalışma durumu

## Amaç
iClip çakmak koleksiyon uygulaması. Seri oluşturma/düzenleme/silme, dört parçalı serilerde sahip olunan parçaları işaretleme, tam/eksik seri filtreleri ve istatistikler sunar. Kamera ve ML Kit OCR ile seri adı/parça numarası okur; Firebase Realtime Database ile verileri tutar.

## Mevcut durum
LocalProjects kaynağından ilk GitHub aktarımı için kaynak ve dokümantasyon hazırlandı; kontrol bulguları docs/VALIDATION.md içinde. Mevcut ürün sürümü `1.0.0+1`; bu aktarım sürümü yükseltmez. Kaynak klasörü korunuyor; bundan sonra bu repository çalışma kopyası kullanılmalı.

## Kararlar
- Ayrı private repository; uygulama kimliği ve sürüm korunur.
- Kısa AGENTS.md + bu durum dosyası yeterli; ek skill/agent oluşturulmadı.
- Runtime/local config ve secret Git dışında. GitHub tek ortak sürüm kaynağı.

## Sonraki adım
İlk işte docs/VALIDATION.md bulgularını kontrol et; ilgili yerel ayar/SDK’ları tamamla, canlı sisteme bağlanmadan gerekli testleri düzelt.

## Bilinen noktalar
Firebase varsayılan collections/default yolu kullanılıyor; kullanıcı ayrımı ve DB güvenlik kuralları ayrıca incelenmeli. Gerçek koleksiyon üzerinde yazma/silme testi yapma. google-services.json ve Apple Firebase config yerelde sağlanmalı. Kamera/ML Kit gerçek cihaz doğrulaması gerektirir. Release şu an debug signing kullanıyor. Mevcut widget testleri Firebase/plugin izolasyonu olmadan çalışmayabilir.
