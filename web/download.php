<?php
declare(strict_types=1);
// APK dosyasını kalıcı storage/downloads/ klasöründen (public/'un dışında) güvenle
// stream eder. Path traversal koruması manage.php ile aynı üç katmanlı yöntem:
// basename() -> sıkı regex -> realpath() ile downloads/ altında olduğunu doğrulama.

require __DIR__ . '/bootstrap.php';

$filename = basename((string) ($_GET['file'] ?? ''));
if ($filename === '' || !preg_match('/^[A-Za-z0-9._-]+\.apk$/', $filename)) {
	http_response_code(400);
	exit('Geçersiz dosya adı.');
}

$downloadsDir = realpath(downloadsDirPath());
$path = $downloadsDir !== false ? realpath($downloadsDir . '/' . $filename) : false;

if ($downloadsDir === false || $path === false || !str_starts_with($path, $downloadsDir . DIRECTORY_SEPARATOR)) {
	http_response_code(404);
	exit('Dosya bulunamadı.');
}

header('Content-Type: application/vnd.android.package-archive');
header('Content-Disposition: attachment; filename="' . basename($path) . '"');
header('Content-Length: ' . (string) filesize($path));
header('X-Content-Type-Options: nosniff');
readfile($path);
