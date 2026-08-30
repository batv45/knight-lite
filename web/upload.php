<?php
declare(strict_types=1);
// Yeni APK build'i yayınlamak için token korumalı endpoint.
// Kullanım (Claude Code tarafından):
//   curl -F "apk=@build/knight-lite.apk" -F "version=0.4.0" -F "note=Faz 4: dünya içeriği" \
//        -H "X-Upload-Token: <token>" https://SENIN_DOMAININ/upload.php

header('Content-Type: application/json; charset=utf-8');

function fail(int $code, string $message): void
{
	http_response_code($code);
	echo json_encode(['ok' => false, 'error' => $message]);
	exit;
}

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
	fail(500, 'config.php eksik. config.example.php dosyasını config.php olarak kopyalayıp token belirleyin.');
}
$config = require $configPath;

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
	fail(405, 'Sadece POST kabul edilir.');
}

$token = $_SERVER['HTTP_X_UPLOAD_TOKEN'] ?? ($_POST['token'] ?? '');
if (!is_string($token) || $token === '' || !hash_equals((string) $config['upload_token'], $token)) {
	fail(401, 'Geçersiz token.');
}

$version = trim((string) ($_POST['version'] ?? ''));
$note = trim((string) ($_POST['note'] ?? ''));
if ($version === '' || !preg_match('/^[A-Za-z0-9._-]+$/', $version)) {
	fail(422, "version alanı zorunlu; sadece harf, rakam, nokta, tire, alt çizgi içerebilir.");
}

if (!isset($_FILES['apk']) || $_FILES['apk']['error'] !== UPLOAD_ERR_OK) {
	fail(422, 'apk dosyası eksik veya yüklenemedi (error kodu: ' . ($_FILES['apk']['error'] ?? 'yok') . ').');
}

$tmpPath = $_FILES['apk']['tmp_name'];
$originalName = (string) $_FILES['apk']['name'];
if (strtolower(pathinfo($originalName, PATHINFO_EXTENSION)) !== 'apk') {
	fail(422, 'Sadece .apk dosyası kabul edilir.');
}

// Gerçek bir ZIP/APK dosyası mı diye magic-byte kontrolü (PK\x03\x04).
$handle = fopen($tmpPath, 'rb');
$magic = $handle ? fread($handle, 4) : '';
if ($handle) {
	fclose($handle);
}
if ($magic !== "PK\x03\x04") {
	fail(422, 'Geçerli bir APK/ZIP dosyası değil.');
}

$downloadsDir = __DIR__ . '/downloads';
if (!is_dir($downloadsDir) && !mkdir($downloadsDir, 0755, true) && !is_dir($downloadsDir)) {
	fail(500, 'downloads/ klasörü oluşturulamadı.');
}

$filename = 'knight-lite-' . $version . '.apk';
$destPath = $downloadsDir . '/' . $filename;
if (!move_uploaded_file($tmpPath, $destPath)) {
	fail(500, 'Dosya kaydedilemedi.');
}

$releasesFile = __DIR__ . '/releases.json';
$defaults = ['project' => 'Knight Lite', 'version' => '0.0.0', 'apk_filename' => null, 'changelog' => []];
$raw = @file_get_contents($releasesFile);
$data = $raw !== false ? (json_decode($raw, true) ?: $defaults) : $defaults;
$data += $defaults;

$data['version'] = $version;
$data['apk_filename'] = $filename;
$data['changelog'][] = [
	'version' => $version,
	'note' => $note !== '' ? $note : 'Yeni build yayınlandı.',
	'uploaded_at' => date('Y-m-d H:i'),
];

file_put_contents($releasesFile, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

echo json_encode(['ok' => true, 'version' => $version, 'filename' => $filename]);
