# Knight Lite — indirme sitesi

Tek sayfalık, framework'süz düz PHP. Üç dosya:

- `index.php` — proje adı, güncel sürüm, değişiklik günlüğü, indirme butonu
- `upload.php` — token korumalı yükleme endpoint'i (yeni APK + sürüm + not gönderilir)
- `manage.php` — token korumalı listeleme/silme endpoint'i, **sadece `downloads/`
  klasörüyle sınırlı** (eski build'leri temizlemek için)

Bu klasör **geliştirme** yeri. Canlıya çıkan yer ayrı bir repo:
**[knight-lite-web](https://github.com/batv45/knight-lite-web)** — Cleavr.io buradan
GitHub entegrasyonuyla otomatik deploy ediyor. Değişiklik yaptıktan sonra monorepo
kökünden `./sync-web.sh "açıklama"` çalıştırıp oraya push et.

## İlk kurulum (knight-lite-web / Cleavr tarafında)

1. PHP 8+ ve (Apache ise) `mod_php`, ya da Nginx + PHP-FPM gerekir.
2. Cleavr bu repoyu site'ın web root'una clone/deploy eder.
3. Sunucuda: `cp config.example.php config.php` ve içine güvenli, rastgele bir token yaz
   (örn. `openssl rand -hex 24`). **`config.php` asla commit edilmez** (.gitignore'da) —
   Cleavr'ın deploy script'ine "eğer config.php yoksa örnekten oluştur" adımı eklenebilir.
4. `cp releases.example.json releases.json` — ilk deploy'da bir kere yapılır, sonrasında
   `upload.php` bu dosyayı günceller (git'e commit edilmez, sunucuda kalıcı kalır).
5. `downloads/` klasörünün PHP tarafından yazılabilir olduğundan emin ol (`chmod 755`).
6. Cleavr'ın deploy script'ine 3-5. adımları "sadece dosya yoksa" mantığıyla eklemek,
   her deploy'da config/releases'in ezilmesini önler.

## Hızlı yerel test

```bash
# knight-lite monorepo kökünden:
php -S 0.0.0.0:8080 -t web
# knight-lite-web reposunun kendi kökünden:
php -S 0.0.0.0:8080 -t .
```

## Yeni build yayınlama (Claude Code tarafından, komut satırından)

```bash
curl -F "apk=@build/knight-lite.apk" \
     -F "version=0.4.0" \
     -F "note=Faz 4: dünya içeriği" \
     -H "X-Upload-Token: <config.php'deki token>" \
     https://SENIN_DOMAININ/upload.php
```
Başarılı olursa `{"ok":true,"version":"0.4.0","filename":"knight-lite-0.4.0.apk"}` döner ve
`index.php` otomatik olarak yeni sürümü gösterir.

## Eski build'leri listeleme / silme (manage.php)

```bash
# Listele
curl -H "X-Upload-Token: <token>" "https://SENIN_DOMAININ/manage.php?action=list"

# Sil (aktif/yayındaki build değilse doğrudan siler)
curl -X POST -H "X-Upload-Token: <token>" \
     -d "filename=knight-lite-0.1.0-beta1.apk" \
     "https://SENIN_DOMAININ/manage.php?action=delete"

# Aktif/yayındaki build'i zorla silmek gerekirse (index.php'deki indirme linki kırılır,
# releases.json'daki apk_filename otomatik null'a çekilir):
curl -X POST -H "X-Upload-Token: <token>" \
     -d "filename=knight-lite-0.1.0-beta1.apk" -d "force=1" \
     "https://SENIN_DOMAININ/manage.php?action=delete"
```

## Güvenlik notları

- `upload.php` ve `manage.php` token'ı `hash_equals` ile sabit zamanlı karşılaştırır
  (timing attack'a karşı).
- Yüklenen dosyanın gerçekten bir ZIP/APK olduğu magic-byte (`PK\x03\x04`) kontrolüyle doğrulanır.
- `version` alanı regex ile kısıtlanır (path traversal / komut enjeksiyonu riski yok).
- `manage.php` sadece `downloads/` klasörüne dokunabilir: dosya adı önce `basename()`
  ile temizlenir, ardından `^[A-Za-z0-9._-]+\.apk$` regex'iyle sınırlanır, son olarak
  `realpath()` ile çözülüp gerçekten `downloads/` altında mı diye tekrar doğrulanır.
  Silme sadece POST ile yapılabilir (GET ile tetiklenemez); aktif/yayındaki build
  `force=1` olmadan silinemez.
- `.htaccess` ile `config.php`'nin doğrudan tarayıcıdan görüntülenmesi engellenir (Apache).
  Nginx kullanıyorsan sunucu config'inde `location ~ config\.php$ { deny all; }` benzeri bir kural ekle.
