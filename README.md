# Invoice Ninja for Railway

Wrapper image behind the Railway template for [Invoice Ninja](https://invoiceninja.com)
5.13.37, the open-source invoicing and billing platform.

## What it changes

- **Runs the application's own initialisation.** The upstream entrypoint only runs
  `invoiceninja-init.sh` when its first argument is `supervisord` or `php-fpm`; a template
  that replaces the command with a shell script skips migrations, the database seed and the
  first-account creation entirely. This image invokes the initialisation explicitly and lets
  it finish before anything binds the public port.
- **Runs the scheduler and two queue workers**, so recurring invoices, reminders and
  autobilling actually fire.
- **Generates `APP_KEY` once per deployment onto the volume**, rather than shipping one
  literal key shared by every deploy. The key protects stored payment-gateway credentials
  and signs sessions.
- **Seeds the administrator before the port opens** and re-applies the credential on every
  boot, so a redeploy is a working password reset. The container refuses to start on an
  empty `IN_PASSWORD` or `IN_USER_EMAIL`.
- **Repairs the volume's ownership.** Railway mounts volumes as uid 0 and the image runs its
  workers as uid 1500.
- **Honours the injected `$PORT`**, which is also the port Railway's healthcheck dials.
- **Keeps uploads on the volume** (`FILESYSTEM_DISK=debian_docker`, i.e.
  `storage/app/public`) with `public/storage` symlinked to it.

## Variables

| Variable | Purpose |
| --- | --- |
| `IN_USER_EMAIL` | Administrator email. Required. |
| `IN_PASSWORD` | Administrator password. Required; re-applied on every boot. |
| `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_PORT` | MySQL connection. |

Everything else has one sane value on Railway and is baked into the image.

## Image

`ghcr.io/bon5co/invoice-ninja-railway:5.13.37`
