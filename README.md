# Knight Lite

Basit, tek oyunculu, 2D üstten görünüm açık dünya aksiyon-RPG (Knight Online'dan
esinlenilmiş "canavar öldür, level kas" döngüsü) — Android hedefli, Godot 4 ile.

Repo iki bağımsız parçadan oluşuyor:

- **[`app/`](app/README.md)** — Godot oyun projesi. Geliştirme durumu, yol haritası,
  headless build/test komutları burada.
- **[`web/`](web/README.md)** — Arkadaşların/senin APK indirebileceğin tek sayfalık
  indirme sitesi + Claude Code'un yeni build'leri yayınlamak için kullandığı
  token korumalı upload endpoint'i.

## Hızlı özet

1. Oyun `app/` içinde Godot 4 ile geliştiriliyor, her fazda headless (Xvfb) test ediliyor.
2. Her yeni build, `web/upload.php`'ye `curl` ile gönderiliyor.
3. Sen (ve arkadaşların) `web/index.php`'nin yayında olduğu adresten güncel APK'yı indiriyorsunuz.
