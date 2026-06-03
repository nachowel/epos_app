# EPOS Windows Installer

Status: approved for the next implementation step.

This installer strategy keeps the local SQLite database in place. The installer
does not run SQL and does not run Drift migrations. Drift migrations run only
when the app starts normally after installation.

## Build

1. Build the Flutter Windows release bundle:

   ```powershell
   flutter build windows --release
   ```

2. Compile the Inno Setup script:

   ```powershell
   ISCC.exe installer\inno\epos_setup.iss
   ```

The script packages `build\windows\x64\runner\Release` into one `Setup.exe`.

## Pre-Install Backup

For an update install, Inno runs the already-installed app before replacing
files:

```text
halfway_cafe_pos.exe --backup-before-upgrade
```

The CLI uses the same production database path resolver as the app. The
installer does not assume the Documents path. If the CLI does not exit with
code `0`, setup stops before updating the app.

Expected backup file:

```text
Documents\backups\pre-install-YYYYMMDD-HHMMSS-epos.sqlite
```

If SQLite sidecar files exist, they are copied too:

```text
pre-install-YYYYMMDD-HHMMSS-epos.sqlite-wal
pre-install-YYYYMMDD-HHMMSS-epos.sqlite-shm
```

## Manual Backup Verification

After running `--backup-before-upgrade`, verify that the backup exists, is not
empty, and matches the source database by byte size and SHA-256 hash:

```powershell
dart run tool\pre_install_backup_verifier.dart
```

If Documents is redirected and the default verifier path is not correct, pass
explicit paths:

```powershell
dart run tool\pre_install_backup_verifier.dart `
  --source "C:\Path\To\epos.sqlite" `
  --backup "C:\Path\To\backups\pre-install-YYYYMMDD-HHMMSS-epos.sqlite"
```

The verifier also checks `.sqlite-wal` and `.sqlite-shm` sidecars when they are
present next to the source database.

The same command also performs a rollback dry-run. It copies the selected backup
to a temporary test database path, copies matching `.sqlite-wal` and
`.sqlite-shm` sidecars when present, opens the restored test database with
SQLite, and requires:

```sql
PRAGMA integrity_check;
```

to return `ok`. This dry-run never writes to the live production
`Documents\epos.sqlite` database.

## Rollback Procedure

1. Close EPOS completely.
2. Confirm no `halfway_cafe_pos.exe` process is running.
3. Copy the selected backup file back over the live database:

   ```text
   Documents\backups\pre-install-YYYYMMDD-HHMMSS-epos.sqlite
   -> Documents\epos.sqlite
   ```

4. If matching sidecars exist in the backup folder, copy them back too:

   ```text
   pre-install-YYYYMMDD-HHMMSS-epos.sqlite-wal -> epos.sqlite-wal
   pre-install-YYYYMMDD-HHMMSS-epos.sqlite-shm -> epos.sqlite-shm
   ```

5. Start EPOS again.

The installer itself does not modify the database. If the startup migration
screen appears, restore from the pre-install backup if needed.

## Migration Safety

Run this checker before increasing `schemaVersion`:

```powershell
dart run tool\check_destructive_migrations.dart
```

It emits warnings for patterns such as `DROP TABLE`, broad `DELETE FROM`, and
legacy table rebuild renames. By default it exits `0`; use `--fail-on-warning`
if CI should fail on any warning.

## Analyzer Note

Targeted analyzer for the installer/startup changes is clean:

```powershell
flutter analyze lib\main.dart lib\core\bootstrap\pre_install_backup_runner.dart lib\presentation\screens\startup\startup_failure_app.dart tool\destructive_migration_checker.dart tool\check_destructive_migrations.dart tool\pre_install_backup_verifier.dart test\core\bootstrap\pre_install_backup_runner_test.dart test\presentation\screens\startup\startup_failure_app_test.dart test\tool\destructive_migration_checker_test.dart test\tool\pre_install_backup_verifier_test.dart
```

Full `flutter analyze` currently fails on unrelated existing repo issues,
including `test\presentation\screens\admin\admin_breakfast_sets_screen_test.dart`
using `TextFormField.readOnly`, plus pre-existing warnings/infos in other
files. Those are not introduced by the installer changes.

Repo health debt: clean up the `TextFormField.readOnly` analyzer error as a
separate task. Leaving it unresolved makes "unrelated analyzer failure" a
permanent dumping ground for future work.
