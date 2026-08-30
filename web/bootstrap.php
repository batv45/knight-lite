<?php
declare(strict_types=1);
// index.php, upload.php, manage.php ve download.php'nin ortak kullandığı yardımcılar.
//
// Cleavr gibi "atomic deploy" yapan platformlarda bu klasörün (web-servable "public")
// içindeki, git'e dahil olmayan dosyalar her deploy'da silinebilir. Cleavr'ın .env
// dosyasını bilinçli olarak bu klasörün BİR ÜSTÜNE koyması da bunu doğruluyor —
// yani gerçek kalıcı konum public/'un üstü. Bu yüzden:
//   - token önce ".." içindeki .env dosyasından okunur (Cleavr'ın koyduğu yer),
//     sonra getenv() (bazı platformlarda gerçekten process env'e de yansır),
//     sonra config.php'ye düşer (yerel/manuel kurulum, en son çare),
//   - releases.json ve downloads/ da aynı kalıcı üst klasöre (storage/) yazılır,
//     böylece public/ içeriği yeniden deploy edilse bile veriler hayatta kalır.
//   - Yerel test (php -S -t web) gibi ".." yazılamayan/garanti olmayan durumlarda
//     otomatik olarak bu klasörün kendisine düşer, hiçbir şey bozulmaz.

function resolveStorageDir(): string
{
	static $resolved = null;
	if ($resolved !== null) {
		return $resolved;
	}

	$parent = dirname(__DIR__);
	$candidate = $parent . '/storage';
	if (is_dir($parent) && is_writable($parent)) {
		if (!is_dir($candidate)) {
			@mkdir($candidate, 0755, true);
		}
		if (is_dir($candidate) && is_writable($candidate)) {
			$resolved = $candidate;
			return $resolved;
		}
	}

	// Kalıcı üst klasöre yazılamıyorsa (ör. yerel test) bu klasörün kendisine düş.
	$resolved = __DIR__;
	return $resolved;
}

function parseEnvFile(string $path): array
{
	if (!is_file($path)) {
		return [];
	}
	$vars = [];
	foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
		$line = trim($line);
		if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
			continue;
		}
		[$key, $value] = explode('=', $line, 2);
		$key = trim($key);
		$value = trim($value);
		if (strlen($value) >= 2) {
			$first = $value[0];
			$last = $value[strlen($value) - 1];
			if (($first === '"' && $last === '"') || ($first === "'" && $last === "'")) {
				$value = substr($value, 1, -1);
			}
		}
		$vars[$key] = $value;
	}
	return $vars;
}

function resolveUploadToken(): ?string
{
	// Cleavr .env dosyasını bu klasörün bir üstüne koyuyor.
	foreach ([dirname(__DIR__) . '/.env', __DIR__ . '/.env'] as $envPath) {
		$vars = parseEnvFile($envPath);
		if (!empty($vars['UPLOAD_TOKEN'])) {
			return (string) $vars['UPLOAD_TOKEN'];
		}
	}

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

function releasesFilePath(): string
{
	return resolveStorageDir() . '/releases.json';
}

function readReleases(): array
{
	$raw = @file_get_contents(releasesFilePath());
	$data = $raw !== false ? (json_decode($raw, true) ?: defaultReleasesData()) : defaultReleasesData();
	return (is_array($data) ? $data : defaultReleasesData()) + defaultReleasesData();
}

function writeReleases(array $data): void
{
	file_put_contents(releasesFilePath(), json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

function downloadsDirPath(): string
{
	$dir = resolveStorageDir() . '/downloads';
	if (!is_dir($dir)) {
		@mkdir($dir, 0755, true);
	}
	return $dir;
}
