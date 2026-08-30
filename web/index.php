<?php
declare(strict_types=1);
// Knight Lite — indirme sayfası. Tek dosya, framework yok.
// releases.json'ı okuyup güncel sürümü + değişiklik günlüğünü gösterir.

require __DIR__ . '/bootstrap.php';

$data = readReleases();

$downloadUrl = null;
if (!empty($data['apk_filename']) && is_file(downloadsDirPath() . '/' . $data['apk_filename'])) {
	$downloadUrl = 'download.php?file=' . rawurlencode((string) $data['apk_filename']);
}

function h(string $s): string
{
	return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h((string) $data['project']) ?> — İndir</title>
<style>
	:root { color-scheme: dark; }
	* { box-sizing: border-box; }
	body {
		margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
		background: #14241a; color: #eef5ee; font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
		padding: 24px;
	}
	.card {
		background: #1c3324; border: 1px solid #2f5138; border-radius: 16px;
		padding: 40px; max-width: 420px; width: 100%; text-align: center;
		box-shadow: 0 20px 50px rgba(0,0,0,0.35);
	}
	h1 { margin: 0 0 4px; font-size: 28px; }
	.version { color: #8fd19e; font-weight: 600; margin-bottom: 24px; }
	.download-btn {
		display: inline-block; width: 100%;
		background: #3ddc84; color: #10241a; font-weight: 700; font-size: 18px;
		padding: 14px 20px; border-radius: 10px; text-decoration: none;
	}
	.download-btn.disabled { background: #3a4a3f; color: #7c8f80; pointer-events: none; }
	.changelog { text-align: left; margin-top: 28px; }
	.changelog h2 { font-size: 13px; color: #a9c7b3; text-transform: uppercase; letter-spacing: 0.05em; }
	.changelog ul { padding-left: 20px; margin: 8px 0 0; }
	.changelog li { margin-bottom: 8px; line-height: 1.4; font-size: 14px; }
	.changelog time { display: block; color: #6f8a78; font-size: 12px; }
	.hint { margin-top: 20px; font-size: 13px; color: #7c9584; }
</style>
</head>
<body>
	<div class="card">
		<h1><?= h((string) $data['project']) ?></h1>
		<div class="version">v<?= h((string) $data['version']) ?></div>

		<?php if ($downloadUrl): ?>
			<a class="download-btn" href="<?= h($downloadUrl) ?>" download>APK'yı İndir</a>
			<div class="hint">Android'de "bilinmeyen kaynaklardan yükleme" izni istenebilir.</div>
		<?php else: ?>
			<span class="download-btn disabled">Henüz yayınlanmış build yok</span>
		<?php endif; ?>

		<?php if (!empty($data['changelog'])): ?>
		<div class="changelog">
			<h2>Güncellemeler</h2>
			<ul>
				<?php foreach (array_reverse((array) $data['changelog']) as $entry): ?>
					<li>
						<strong>v<?= h((string) ($entry['version'] ?? '')) ?>:</strong>
						<?= h((string) ($entry['note'] ?? '')) ?>
						<?php if (!empty($entry['uploaded_at'])): ?>
							<time><?= h((string) $entry['uploaded_at']) ?></time>
						<?php endif; ?>
					</li>
				<?php endforeach; ?>
			</ul>
		</div>
		<?php endif; ?>
	</div>
</body>
</html>
