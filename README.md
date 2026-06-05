# AppStoreBackup

Backup your App Store apps before updating them.

Because the macOS App Store does not have versioning, use this app to make a backup copy of your apps before updating.
Really useful if you are a cloud drive user and want to build the app for different computers.

A native macOS utility that uses `mas-cli` to list outdated App Store apps, backs up the original app bundles, then runs the update. Backups (suffixed with `-AppStoreBackup`) can be browsed and deleted from a separate panel.

## Requirements

- macOS 14.0+
- [mas-cli](https://github.com/mas-cli/mas) (installed automatically via Homebrew if missing)

## Build

```bash
./build.sh
```

When run, a dialog box will prompt you to select a suffix for the app name:
- **No Suffix**: Generates `AppStoreBackup.app`.
- **Computer Name**: Appends the computer's local hostname (e.g. `AppStoreBackup_MacBook-Air.app`).
- **Custom Name**: Prompts you to enter a custom suffix (sanitized to alphanumeric characters, dashes, and underscores).

This allows building and organizing the application for multiple different computers directly from a cloud drive.

## Usage

1. **Update Apps** — scans for outdated App Store apps, backs up each selected app, then runs the upgrade via `mas upgrade`.
2. **Delete Backups** — lists all `-AppStoreBackup` bundles found in `/Applications` and lets you remove them.
