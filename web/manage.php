<?php
declare(strict_types=1);
// downloads/ klasörünü yönetmek için token korumalı endpoint: listele + sil.
// Güvenlik: bu endpoint SADECE downloads/ klasörüne dokunabilir.
//   - Dosya adı basename() ile temizlenir (herhangi bir "/" veya ".." atılır),
//   - ardından sıkı bir regex ile ^[A-Za-z0-9._-]+\.apk$ formatına zorlanır,
//   - son olarak realpath() ile çözülüp gerçekten downloads/ altında mı diye
//     ikinci kez doğrulanır (symlink vb. kaçış senaryolarına karşı).
// Bu üç katman birlikte path traversal'ı imkansız kılar.
//
// Kullanım (Claude Code tarafından):
//   curl -H "X-Upload-Token: <token>" "https://SENIN_DOMAININ/manage.php?action=list"
//   curl -X POST -H "X-Upload-Token: <token>" -d "filename=knight-lite-0.3.0.apk" \
//        https://SENIN_DOMAININ/manage.php?action=delete

require __DIR__ . '/bootstrap.php';

header('Content-Type: application/json; charset=utf-8');

function fail(int $code, string $message): void
{
	http_response_code($code);
	echo json_encode(['ok' => false, 'error' => $message]);
	exit;
}

$expectedToken = resolveUploadToken();
if ($expectedToken === null) {
	fail(500, 'Token yapılandırılmamış: UPLOAD_TOKEN ortam değişkenini ayarla ya da config.php oluştur.');
}

$token = $_SERVER['HTTP_X_UPLOAD_TOKEN'] ?? ($_POST['token'] ?? ($_GET['token'] ?? ''));
if (!is_string($token) || $token === '' || !hash_equals($expectedToken, $token)) {
	fail(401, 'Geçersiz token.');
}

$downloadsDir = realpath(__DIR__ . '/downloads');
if ($downloadsDir === false) {
	fail(500, 'downloads/ klasörü bulunamadı.');
}

/**
 * "filename"i downloads/ klasörü içinde güvenli bir gerçek yola çözer.
 * Herhangi bir path traversal / geçersiz karakter / downloads/ dışına çıkma
 * durumunda null döner.
 */
function resolveDownloadPath(string $downloadsDir, string $filename): ?string
{
	$filename = basename($filename);
	if ($filename === '' || !preg_match('/^[A-Za-z0-9._-]+\.apk$/', $filename)) {
		return null;
	}
	$real = realpath($downloadsDir . DIRECTORY_SEPARATOR . $filename);
	if ($real === false) {
		return null;
	}
	if (!str_starts_with($real, $downloadsDir . DIRECTORY_SEPARATOR)) {
		return null;
	}
	return $real;
}

$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($action === 'list') {
	$releases = readReleases();
	$activeFile = $releases['apk_filename'];

	$files = [];
	foreach ((scandir($downloadsDir) ?: []) as $entry) {
		$path = $downloadsDir . DIRECTORY_SEPARATOR . $entry;
		if (!is_file($path) || !preg_match('/^[A-Za-z0-9._-]+\.apk$/', $entry)) {
			continue;
		}
		$files[] = [
			'filename' => $entry,
			'size_bytes' => filesize($path),
			'modified_at' => date('Y-m-d H:i:s', filemtime($path)),
			'active' => $entry === $activeFile,
		];
	}
	usort($files, fn($a, $b) => $b['modified_at'] <=> $a['modified_at']);

	echo json_encode(['ok' => true, 'files' => $files]);
	exit;
}

if ($action === 'delete') {
	if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
		fail(405, 'Silme işlemi sadece POST ile yapılabilir.');
	}

	$filename = basename((string) ($_POST['filename'] ?? ''));
	$force = (($_POST['force'] ?? '') === '1');

	$releases = readReleases();
	$isActive = $filename !== '' && $filename === $releases['apk_filename'];
	if ($isActive && !$force) {
		fail(409, 'Bu dosya şu an yayında olan aktif build. Silmek için force=1 gönder.');
	}

	$realPath = resolveDownloadPath($downloadsDir, $filename);
	if ($realPath === null) {
		fail(404, 'Dosya bulunamadı ya da geçersiz dosya adı.');
	}

	if (!unlink($realPath)) {
		fail(500, 'Dosya silinemedi.');
	}

	if ($isActive) {
		$releases['apk_filename'] = null;
		writeReleases($releases);
	}

	echo json_encode(['ok' => true, 'deleted' => basename($realPath)]);
	exit;
}

fail(400, "Geçersiz action. 'list' ya da 'delete' kullan.");
