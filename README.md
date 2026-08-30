# Knight Lite

Basit, tek oyunculu, 2D üstten görünüm açık dünya aksiyon-RPG (Knight Online'dan
esinlenilmiş "canavar öldür, level kas" döngüsü) — Android hedefli, Godot 4 ile.

Repo iki bağımsız parçadan oluşuyor:

- **[`app/`](app/README.md)** — Godot oyun projesi. Geliştirme durumu, yol haritası,
  headless build/test komutları burada.
- **[`web/`](web/README.md)** — Arkadaşların/senin APK indirebileceğin tek sayfalık
  indirme sitesi + Claude Code'un yeni build'leri yayınlamak için kullandığı
  token korumalı upload endpoint'i.

`web/` burada **geliştiriliyor**, ama canlıya çıkan yer ayrı bir repo:
**[knight-lite-web](https://github.com/batv45/knight-lite-web)** — Cleavr.io buradan
GitHub entegrasyonuyla otomatik deploy ediyor. Değişiklik yaptıkça:
```bash
./sync-web.sh "değişiklik açıklaması"
```
komutu `web/`'i `../knight-lite-web` klonuna senkronize edip push eder (ilk seferde
`git clone git@github.com:batv45/knight-lite-web.git ../knight-lite-web` gerekir).

## Hızlı özet

1. Oyun `app/` içinde Godot 4 ile geliştiriliyor, her fazda headless (Xvfb) test ediliyor.
2. `web/` içindeki site kodu değiştikçe `sync-web.sh` ile `knight-lite-web` reposuna
   push ediliyor, Cleavr oradan otomatik deploy ediyor.
3. Her yeni APK build'i, canlıdaki `upload.php`'ye `curl` ile gönderiliyor.
4. Sen (ve arkadaşların) sitenin yayında olduğu adresten güncel APK'yı indiriyorsunuz.

## Altyapı / erişim bilgileri

| Ne | Nerede |
|---|---|
| Oyun kaynak kodu | https://github.com/batv45/knight-lite (bu repo) |
| Web sitesi kaynak kodu (deploy hedefi) | https://github.com/batv45/knight-lite-web |
| Canlı indirme sitesi | https://knight.batv.dev |
| Hosting/deploy | Cleavr.io, `knight-lite-web` reposunu GitHub entegrasyonuyla izliyor |
| Upload token | Sadece sunucudaki `config.php` içinde (repoya commit edilmez); Claude Code'un yerel ortamında `~/.secrets/knight_lite_upload_token.txt` içinde saklanıyor |
| GitHub push erişimi | Hesap genelinde tanımlı bir SSH deploy key ile (`~/.ssh/knight_lite_deploy`) |

### Versiyon numaralandırma kuralı

Semantic versioning + beta suffix: `MAJOR.MINOR.0-betaN`. Aynı minor içinde her yeni
build'de sadece beta sayacı artar (`0.1.0-beta1` → `0.1.0-beta2` → ...). Gerçek bir
milestone'a ulaşılınca MINOR artırılır ve beta sayacı 1'e sıfırlanır (`0.2.0-beta1`).
Şu an geçerli aralık: `0.1.0-betaN`. Güncel sürüm `web/releases.json` → `version`
alanından ya da canlı sitedeki `https://knight.batv.dev/releases.json`'dan görülebilir.

### Yeni build yayınlama komutu

```bash
TOKEN=$(cat ~/.secrets/knight_lite_upload_token.txt)
curl -F "apk=@app/build/knight-lite.apk" \
     -F "version=0.1.0-betaN" \
     -F "note=<kısa açıklama>" \
     -H "X-Upload-Token: $TOKEN" \
     https://knight.batv.dev/upload.php
```
