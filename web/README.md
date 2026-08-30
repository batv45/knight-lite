# Knight Lite — indirme sitesi

Tek sayfalık, framework'süz düz PHP. Dosyalar:

- `index.php` — proje adı, güncel sürüm, değişiklik günlüğü, indirme butonu
- `download.php` — APK'yı kalıcı depodan (storage/) güvenle stream eder
- `upload.php` — token korumalı yükleme endpoint'i (yeni APK + sürüm + not gönderilir)
- `manage.php` — token korumalı listeleme/silme endpoint'i
- `bootstrap.php` — hepsinin kullandığı ortak yardımcılar (token çözümleme, kalıcı veri yolu)

Bu klasör **geliştirme** yeri. Canlıya çıkan yer ayrı bir repo:
**[knight-lite-web](https://github.com/batv45/knight-lite-web)** — Cleavr.io buradan
GitHub entegrasyonuyla otomatik deploy ediyor. Değişiklik yaptıktan sonra monorepo
kökünden `./sync-web.sh "açıklama"` çalıştırıp oraya push et.

## Mimari: neden "public'in bir üstü" önemli

Cleavr gibi atomic-deploy yapan platformlarda her deploy, bu klasörün (web-servable
"public") içeriğini komple değiştirir/temizler — git'e dahil olmayan dosyalar
(yüklenen APK'lar, sürüm kaydı) kaybolur. Cleavr'ın `.env` dosyasını bilinçli olarak
bu klasörün **bir üstüne** koyması da bunu doğruluyor: gerçek kalıcı konum orası.

Bu yüzden `bootstrap.php`:
- Token'ı önce `../.env` dosyasından okur (`UPLOAD_TOKEN=...` satırı), sonra
  `getenv('UPLOAD_TOKEN')`'a, sonra `config.php`'ye düşer (yerel/manuel fallback).
- `releases.json` ve indirilen APK'ları (`downloads/`) bu klasörün içine değil,
  **`../storage/`** (bir üst, kalıcı) klasörüne yazar. Böylece kod her deploy'landığında
  yeniden oluşsa bile veriler hayatta kalır — **manuel müdahale gerekmez.**
- Yerel testte (`php -S -t web`) "bir üst" klasör de yazılabilir olduğundan bu düzen
  zaten çalışır (monorepo kökünde bir `storage/` oluşur, .gitignore'da).

`downloads/` artık public'te olmadığı için APK doğrudan statik dosya linkiyle değil,
`download.php?file=...` üzerinden stream edilir (aynı path-traversal korumalarıyla).

## İlk kurulum

Genelde **hiçbir şey yapmana gerek yok** — ilk `upload.php` çağrısı `storage/` klasörünü
ve `releases.json`'ı kendiliğinden oluşturur. Tek gereken: Cleavr'da `UPLOAD_TOKEN`
ortam değişkeninin (ya da `.env` dosyasının) tanımlı olması.

Eğer `.env`/env var hiç çalışmazsa (bazı PHP-FPM kurulumlarında env değişkenleri pool'a
geçmeyebilir), fallback olarak:
```bash
cp config.example.php config.php
# içine gerçek token'ı yaz
```
Bu dosya deploy'da silinebilir ama en azından `.env` çalışana kadar geçici çözüm olur.

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
     -F "version=0.1.0-beta2" \
     -F "note=Faz 4: dünya içeriği" \
     -H "X-Upload-Token: <token>" \
     https://SENIN_DOMAININ/upload.php
```
Başarılı olursa `{"ok":true,"version":"0.1.0-beta2","filename":"knight-lite-0.1.0-beta2.apk"}`
döner ve `index.php` otomatik olarak yeni sürümü gösterir.

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
- `manage.php` ve `download.php` sadece `storage/downloads/` klasörüne dokunabilir:
  dosya adı önce `basename()` ile temizlenir, ardından `^[A-Za-z0-9._-]+\.apk$`
  regex'iyle sınırlanır, son olarak `realpath()` ile çözülüp gerçekten o klasörün
  altında mı diye tekrar doğrulanır.
- Silme sadece POST ile yapılabilir (GET ile tetiklenemez); aktif/yayındaki build
  `force=1` olmadan silinemez.
- `.htaccess` ile `config.php`'nin doğrudan tarayıcıdan görüntülenmesi engellenir (Apache).
  Nginx kullanıyorsan sunucu config'inde `location ~ config\.php$ { deny all; }` benzeri bir kural ekle.
