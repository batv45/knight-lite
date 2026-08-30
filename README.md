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
