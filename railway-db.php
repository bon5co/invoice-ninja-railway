<?php
// Creates the application database if it is missing and waits for MySQL to
// accept connections. Railway's MySQL image is started without a database name,
// because a literal template variable publishes as a blank required field.

$host = getenv('DB_HOST') ?: '127.0.0.1';
$port = getenv('DB_PORT') ?: '3306';
$user = getenv('DB_USERNAME') ?: 'root';
$pass = (string) getenv('DB_PASSWORD');
$name = getenv('DB_DATABASE') ?: 'ninja';

$last = '';
for ($i = 0; $i < 90; $i++) {
    try {
        $pdo = new PDO("mysql:host={$host};port={$port}", $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        $pdo->exec("CREATE DATABASE IF NOT EXISTS `{$name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        echo "[railway] database {$name} ready\n";
        exit(0);
    } catch (Exception $e) {
        $last = $e->getMessage();
        sleep(2);
    }
}

fwrite(STDERR, "[railway] FATAL: database unreachable after 180s: {$last}\n");
exit(1);
