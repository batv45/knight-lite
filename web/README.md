# Knight Lite — indirme sitesi

Tek sayfalık, framework'süz düz PHP. İki dosya:

- `index.php` — proje adı, güncel sürüm, değişiklik günlüğü, indirme butonu
- `upload.php` — token korumalı yükleme endpoint'i (yeni APK + sürüm + not gönderilir)

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

## Güvenlik notları

- `upload.php` token'ı `hash_equals` ile sabit zamanlı karşılaştırır (timing attack'a karşı).
- Yüklenen dosyanın gerçekten bir ZIP/APK olduğu magic-byte (`PK\x03\x04`) kontrolüyle doğrulanır.
- `version` alanı regex ile kısıtlanır (path traversal / komut enjeksiyonu riski yok).
- `.htaccess` ile `config.php`'nin doğrudan tarayıcıdan görüntülenmesi engellenir (Apache).
  Nginx kullanıyorsan sunucu config'inde `location ~ config\.php$ { deny all; }` benzeri bir kural ekle.
