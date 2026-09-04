<?php
// Re-applies the deployer's admin credential on every boot, so a redeploy is a
// working reset. Invoice Ninja's only other recovery path is an emailed reset
// link, and a fresh Railway deploy has no mail transport configured.
//
// Run with: php artisan tinker /railway-seed.php

use App\Models\Account;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

$email = trim((string) getenv('IN_USER_EMAIL'));
$secret = (string) getenv('IN_PASSWORD');

if ($email === '' || $secret === '') {
    echo "[railway] seed skipped: empty credential\n";
    return;
}

if (Account::count() === 0) {
    Artisan::call('ninja:create-account', ['--email' => $email, '--password' => $secret]);
    echo "[railway] admin account created\n";
    return;
}

$user = User::withTrashed()->where('email', $email)->first();

if ($user === null) {
    Artisan::call('ninja:create-account', ['--email' => $email, '--password' => $secret]);
    echo "[railway] admin account created (existing install)\n";
    return;
}

$user->password = Hash::make($secret);
$user->save();
echo "[railway] admin credential re-applied\n";
