# Android APK yayın rehberi

## Düzen

APK dosyaları Git repository’ye eklenmez; GitHub Releases asset olarak saklanır. Sabit son sürüm bağlantısı `/releases/latest/download/Clipper.apk`, sürüm geçmişi `downloads/README.md` içindedir. Tablo yayımlanmış, APK asset’i tamamlanmış sürümlerden üretilir; tarihler Europe/Istanbul saat dilimindedir.

## Yeni sürüm

1. Kod değişikliğini test edin.
2. `pubspec.yaml` içindeki sürümü ve `+` sonrasındaki Android build numarasını artırın. Build numarası önceki yayınların hepsinden büyük olmalı.
3. Değişikliği `main` dalına normal commit/push ile gönderin.
4. `Android APK release` Actions akışı analiz/test, imzalı release build, sürüm etiketi, APK/SHA256SUMS yükleme ve downloads güncellemesini tamamlar.
5. Kullanıcı aynı son sürüm bağlantısından yeni APK’yı indirip mevcut uygulamasının üzerine kurar. İmza anahtarı ve paket kimliği korunmalıdır.

`v<version>+<build>` etiketiyle yayın da desteklenir. Actions sayfasından `workflow_dispatch` ile başarısız yayın tekrar denenebilir. Yayımlanmış APK yeniden yazılmaz; yeni sürüm gerekir. Downloads güncellemesi başarısızsa yayımlanan APK korunur ve tekrar çalıştırma tabloyu onarır.

## Repository Secrets

- `FIREBASE_ANDROID_CONFIG`: Firebase Android istemci JSON’u.
- `CLIPPER_LOGIN_CONFIG`: kullanıcı adı, rastgele salt, PBKDF2-HMAC-SHA256 doğrulama özeti ve iteration sayısı. Düz metin parola saklanmaz.
- `ANDROID_KEYSTORE_BASE64`: kalıcı Android release anahtarı.
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`: imzalama parametreleri.

Yalnız güvenilen repository yöneticileri workflow dosyasını ve Secrets’ı değiştirebilmelidir. Public pull request event’i release workflow’unu çalıştırmaz. Dosyalar derleme sırasında özel geçici dosyalara yazılır; cache veya yayın asset’i yapılmaz ve iş sonunda temizlenir. Loglarda değerler yazdırılmaz. İmzalama anahtarını güncellemelerde yenilemeyin; kaybı mevcut kurulumların üzerine yeni sürüm yüklenmesini engeller. Yerel yedek `.release/` altında Git dışında korunur.

## Yerel release

Yetkili yerel ortam, bu altı Secrets’ın eşdeğerini ortam değişkenleri olarak sağladıktan sonra:

```sh
python3 scripts/prepare_release.py
flutter build apk --release --no-pub --dart-define-from-file=.release/login.json
```

Gerçek değerleri komuta, kaynak koda, issue/PR açıklamasına veya loga yapıştırmayın. `scripts/publish_release.py` yalnız güvenilen release build sonrasında ve doğru repository için çalıştırılır.

## Güvenlik sınırı

Bu kullanıcı talebiyle cihazda çalışan bir uygulama kilididir. Başarılı girişten önce koleksiyon repository’si oluşturulmaz; oturum işareti cihazın güvenli deposunda tutulur. Parolanın kendisi APK’ya eklenmez; doğrulama özeti eklenir. APK’yı inceleyen kişi bu kontrolü atlayabilir veya özeti çevrimdışı deneyebilir. Firebase yönetim erişimi olmadığı için sunucu kuralları değiştirilmedi; doğrudan Firebase erişimini bu kilit korumaz. Kullanıcı bu sınırı kabul ederek Secrets ile yayın düzenini seçti.
