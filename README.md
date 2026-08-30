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

## Sunucu tarafında hazır altyapı

Bu proje sende (Raspberry Pi, monitörsüz) değil, Claude Code'un çalıştığı uzak
sunucuda tamamen komut satırından geliştirilip test ediliyor. Sunucuda kurulu:

- Godot 4.7.2 (headless çalışabilen resmi Linux binary) — `godot4`
- Android export template'leri + Android SDK (platform-tools, build-tools 34.0.0)
- Debug keystore (`~/.android/debug.keystore`) — otomatik imzalama için
- Xvfb + yazılımsal (llvmpipe) OpenGL — ekran olmadan render/screenshot almak için

Yani sen hiçbir şey kurmuyorsun; ben kod yazıp burada derliyor, ekran görüntüsüyle
doğruluyor ve APK üretiyorum.

### Görsel doğrulama (screenshot)
Ekran olmadan oyunun nasıl göründüğünü kontrol etmek için:
```bash
xvfb-run -a --server-args="-screen 0 1280x720x24" \
  godot4 --path . -- --screenshot
```
`screenshot.png` dosyasına kaydedilir (bkz. `world.gd` içindeki dev hook).

### APK üretimi
```bash
godot4 --headless --path . --export-debug "Android" build/knight-lite.apk
```
Çıktı: `build/knight-lite.apk` (imzalı, kurulabilir debug APK).

### APK'yı telefona nasıl alacağız?
Henüz karara bağlamadık — sunucudan telefona dosya aktarımı için bir yöntem
seçmemiz lazım (örn. git deposuna push edip oradan indirme, ya da başka bir
yöntem). Bir sonraki adımda konuşulacak.

## Kendi bilgisayarında açmak istersen (opsiyonel)

Bu adımlar zorunlu değil — yukarıdaki sunucu tabanlı akış yeterli. Yine de
görsel editörde gezinmek istersen:
1. [Godot 4.7+](https://godotengine.org/download) indir.
2. Godot'u aç → "Import" → bu klasördeki `project.godot` dosyasını seç.
3. Üstteki Play (▶ / F5) tuşuna bas.
4. Kontroller: ok tuşları/WASD veya sol alttaki sanal joystick (mouse ile de sürüklenebilir).

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
