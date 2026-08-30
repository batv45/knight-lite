# Knight Lite

Basit, tek oyunculu, 2D üstten görünüm açık dünya aksiyon-RPG (Knight Online'dan
esinlenilmiş "canavar öldür, level kas" döngüsü). Godot 4 + GDScript.

## Şu anki durum: Faz 1 — Hareket, kamera, dokunmatik kontrol

Bu fazda oynanabilir olan:
- Karakter (mavi kare, placeholder) WASD / ok tuşlarıyla hareket eder
- Kamera karakteri takip eder, dünya sınırları içinde kalır
- Sol alt köşede sanal joystick var (dokunmatik veya mouse ile sürükleyerek)
- PC'de mouse ile de test edilebilir (`emulate_touch_from_mouse` açık), gerçek
  cihazda parmakla aynı şekilde çalışır

Henüz yok: savaş, canavarlar, level/XP, gerçek asset'ler — bunlar sonraki fazlarda.

## Nasıl çalıştırılır

1. [Godot 4.2+](https://godotengine.org/download) indir (Standard sürüm yeterli).
2. Godot'u aç → "Import" → bu klasördeki `project.godot` dosyasını seç.
3. Üstteki Play (▶ / F5) tuşuna bas.
4. Kontroller:
   - Klavye: ok tuşları veya WASD
   - Mouse/dokunmatik: sol altta beliren yarı saydam joystick'i sürükle

## Mimari notları

- Sahne dosyaları (`.tscn`) bilinçli olarak minimal: sadece kök node + script.
  Gerçek node ağacı (görsel, çarpışma şekli, kamera, joystick) her sahnenin
  kendi script'inde `_ready()` içinde runtime'da kuruluyor. Bu sayede
  görsel editör olmadan (Claude Code üzerinden) yazılan sahneler editörde
  bozuk açılma riski taşımıyor.
- `InputBridge` (autoload, `scripts/input_bridge.gd`) klavye ve dokunmatik
  girdiyi tek bir arayüzde birleştirir. Yeni script'ler hep
  `InputBridge.get_move_vector()` kullanmalı, `Input` sınıfına doğrudan gitmemeli.
- Placeholder görseller (`ColorRect`) asset paketi seçilince kolayca gerçek
  sprite/`AnimatedSprite2D` ile değiştirilecek — oyun mantığı etkilenmeyecek.

## Yol haritası

- [x] Faz 1 — İskelet, hareket, kamera, touch kontrol
- [ ] Faz 2 — Savaş çekirdeği (saldırı, HP, ölüm/respawn, 1 canavar tipi)
- [ ] Faz 3 — Leveling + loot (XP, level atlama, stat artışı, item drop)
- [ ] Faz 4 — Dünya içeriği (birden fazla bölge/canavar tipi, zorluk eğrisi)
- [ ] Faz 5 — Polish + Android export (HUD, ses, save/load, gerçek cihaz testi)
