# macOS Laptop Migration Tool

Simple one-script solution for backing up and restoring macOS setups for developers.

## Quick Start

```bash
# Backup current laptop
./migrate.sh backup

# Restore on new laptop  
./migrate.sh restore ~/Downloads/backup.zip
```

## What it backs up
- Homebrew packages (Brewfile)
- SSH keys and config
- Projects folder (cleaned of node_modules)
- Cursor editor settings
- Git configuration
- Shell aliases and PATH

## What syncs automatically
- iCloud passwords
- 1Password (after sign-in)
- Calendar, Mail, Contacts

## Installation

```bash
curl -O https://raw.githubusercontent.com/matthew-gill/osx-laptop-migration/main/migrate.sh
chmod +x migrate.sh
```

---

## Files

- `migrate.sh` - Main migration script
- `.gitignore` - Excludes sensitive/local files
- `README.md` - This file

Backup files are never committed to git for privacy.