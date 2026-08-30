<?php
declare(strict_types=1);
// index.php, upload.php ve manage.php'nin ortak kullandığı yardımcılar.
//
// Cleavr gibi "atomic deploy" yapan platformlarda config.php/releases.json gibi
// git'e dahil olmayan dosyalar her deploy'da silinebilir. Bunu tolere etmek için:
//   - token önce UPLOAD_TOKEN ortam değişkeninden okunur (deploy'a bağlı değil,
//     kalıcıdır), yoksa config.php'ye düşer (yerel/manuel kurulum),
//   - releases.json yoksa varsayılan değerlerle kendiliğinden oluşturulur
//     (changelog geçmişi kaybolur ama site hata vermez).

function resolveUploadToken(): ?string
{
	$envToken = getenv('UPLOAD_TOKEN');
	if (is_string($envToken) && $envToken !== '') {
		return $envToken;
	}

	$configPath = __DIR__ . '/config.php';
	if (is_file($configPath)) {
		$config = require $configPath;
		if (is_array($config) && !empty($config['upload_token'])) {
			return (string) $config['upload_token'];
		}
	}

	return null;
}

function defaultReleasesData(): array
{
	return ['project' => 'Knight Lite', 'version' => '0.0.0', 'apk_filename' => null, 'changelog' => []];
}

function readReleases(): array
{
	$raw = @file_get_contents(__DIR__ . '/releases.json');
	$data = $raw !== false ? (json_decode($raw, true) ?: defaultReleasesData()) : defaultReleasesData();
	return (is_array($data) ? $data : defaultReleasesData()) + defaultReleasesData();
}

function writeReleases(array $data): void
{
	file_put_contents(__DIR__ . '/releases.json', json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}
