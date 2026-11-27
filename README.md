# Antigravity Community Installer (Ubuntu 26.04 LTS)

A clean, transparent, zero-bloat Bash installer for **Antigravity** on **Ubuntu 26.04 LTS** (and Ubuntu 24.04+). 

Unlike wrapper scripts that fetch unverified remote payloads during execution, `install-antigravity.sh` works strictly offline using the local `.tar.gz` archive you provide.

---

## Features

- **Zero External Downloads:** Operates 100% locally on your downloaded `.tar.gz` archive—no `curl` or hidden network calls.
- **Flexible Installation Scopes:**
  - **System-wide (`--system`):** Installs to `/opt/antigravity` with CLI symlink in `/usr/local/bin/antigravity`.
  - **User-local (`--user`):** Installs to `~/Applications/antigravity` with CLI symlink in `~/.local/bin/antigravity`.
- **Smart Archive Discovery:** Pass the path to your `.tar.gz` directly, or omit it to let the script automatically find it in your current directory or `~/Downloads`.
- **Ubuntu 26.04 LTS Sandbox Compatibility:** Automatically configures an `/etc/apparmor.d/antigravity` profile for system-wide installs so Electron/Chromium unprivileged user namespaces (`userns`) work out of the box.
- **Full Desktop Integration:** Installs the application icon, registers the `.desktop` launcher entry (with "New Empty Window" quick action), and updates desktop/icon caches.
- **Clean Uninstaller:** Includes a `--uninstall` flag to cleanly remove all installed files, symlinks, desktop entries, and AppArmor profiles.

---

## Quick Start

1. **Download** the official Antigravity Linux `.tar.gz` archive.
2. **Make the installer executable:**
   ```bash
   chmod +x install-antigravity.sh
   ```
3. **Run the installer:**
   ```bash
   ./install-antigravity.sh /path/to/Antigravity-linux-x64.tar.gz
   ```
   *(If the archive is already in your current folder or `~/Downloads`, you can simply run `./install-antigravity.sh`.)*

---

## Usage & Options

```text
Usage:
  install-antigravity.sh [OPTIONS] [ARCHIVE_PATH]

Options:
  --system          Install system-wide into /opt/antigravity (requires sudo)
  --user            Install for current user into ~/Applications/antigravity
  --uninstall       Remove an existing installation (prompts for scope if unspecified)
  -h, --help        Show this help message and exit

Arguments:
  ARCHIVE_PATH      Optional path to the Antigravity .tar.gz file. If omitted,
                    the script searches the current directory and ~/Downloads.
```

### Examples

**Interactive install (auto-finds `.tar.gz` and prompts for system vs. user):**
```bash
./install-antigravity.sh
```

**System-wide install from a specific directory:**
```bash
./install-antigravity.sh --system ~/Downloads/antigravity-1.0.0.tar.gz
```

**User-only install (no `sudo` required):**
```bash
./install-antigravity.sh --user ~/Downloads/antigravity-1.0.0.tar.gz
```

**Upgrading an existing version:**
Simply run the installer again with the new `.tar.gz` archive and the same scope (`--system` or `--user`). It will cleanly replace the existing installation directory.

---

## Installed File Locations

| Component | System-Wide (`--system`) | User-Local (`--user`) |
| :--- | :--- | :--- |
| **Application Files** | `/opt/antigravity/` | `~/Applications/antigravity/` |
| **CLI Binary Symlink** | `/usr/local/bin/antigravity` | `~/.local/bin/antigravity` |
| **Desktop Entry** | `/usr/share/applications/antigravity.desktop` | `~/.local/share/applications/antigravity.desktop` |
| **Application Icon** | `/usr/share/icons/hicolor/512x512/apps/antigravity.png` | `~/.local/share/icons/hicolor/512x512/apps/antigravity.png` |
| **AppArmor Profile** | `/etc/apparmor.d/antigravity` | *N/A (requires root)* |

---

## Notes for Ubuntu 26.04 LTS Users

- **AppArmor & `chrome-sandbox`:** Ubuntu 24.04 and 26.04 LTS restrict unprivileged user namespaces via AppArmor. When installing with `--system`, this script automatically creates `/etc/apparmor.d/antigravity` and reloads AppArmor so Antigravity launches cleanly without sandbox errors. If you choose `--user` and encounter a sandbox error on launch, either reinstall with `--system` or launch via `antigravity --no-sandbox`.
- **`~/.local/bin` in `PATH`:** If you choose `--user` and `antigravity` is not recognized in your terminal, ensure `~/.local/bin` is in your `$PATH`:
  ```bash
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
  ```

---

## Uninstalling

To cleanly remove Antigravity and all associated desktop/system files:

```bash
# Uninstall system-wide installation
./install-antigravity.sh --uninstall --system

# Uninstall user-local installation
./install-antigravity.sh --uninstall --user
```

---

## License

This installer script is released into the public domain / MIT License for community use.