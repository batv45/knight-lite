# Knight Lite — indirme sitesi

Tek sayfalık, framework'süz düz PHP. İki dosya:

- `index.php` — proje adı, güncel sürüm, değişiklik günlüğü, indirme butonu
- `upload.php` — token korumalı yükleme endpoint'i (yeni APK + sürüm + not gönderilir)

## İlk kurulum

1. PHP 8+ ve (Apache ise) `mod_php`, ya da Nginx + PHP-FPM olan bir hosting/sunucu gerekir.
2. Bu `web/` klasörünü sunucuya kopyala (veya sunucuda bu repoyu clone'la, web root'u bu klasöre işaretle).
3. `cp config.example.php config.php` ve içine güvenli, rastgele bir token yaz
   (örn. `openssl rand -hex 24`). **`config.php` asla commit edilmez** (.gitignore'da).
4. `cp releases.example.json releases.json` — ilk çalıştırmada gerçek veri dosyası oluşur,
   sonrasında `upload.php` bu dosyayı günceller (git'e commit edilmez, sunucuda kalıcı kalır).
5. `downloads/` klasörünün PHP tarafından yazılabilir olduğundan emin ol (`chmod 755` yeterli olmalı).

## Hızlı yerel test (PHP'nin kendi sunucusuyla, Apache/Nginx gerekmez)

```bash
php -S 0.0.0.0:8080 -t web
```
Tarayıcıdan `http://SUNUCU_IP:8080` adresine git.

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
