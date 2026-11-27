#!/usr/bin/env bash
# ==============================================================================
# Antigravity Community Installer (Ubuntu 26.04 LTS)
# ==============================================================================
# Description:
#   A clean, transparent, zero-bloat installer for Antigravity from a local
#   .tar.gz archive. Supports system-wide (/opt) or user-local (~/Applications)
#   installations, sets up CLI symlinks, configures AppArmor/sandbox permissions
#   if needed on Ubuntu 24.04/26.04+, and registers the desktop entry & icons.
#
# Usage:
#   ./install-antigravity.sh [path/to/antigravity-*.tar.gz]
#   ./install-antigravity.sh --help
# ==============================================================================

set -euo pipefail

# --- Styling & Colors ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; }

# --- Usage / Help ---
show_help() {
    cat <<EOF
${BOLD}Antigravity Community Installer${RESET}

Usage:
  $(basename "$0") [OPTIONS] [ARCHIVE_PATH]

Options:
  --system          Install system-wide into /opt/antigravity (requires sudo)
  --user            Install for current user into ~/Applications/antigravity
  --uninstall       Remove an existing installation (prompts for scope if unspecified)
  -h, --help        Show this help message and exit

Arguments:
  ARCHIVE_PATH      Optional path to the Antigravity .tar.gz file. If omitted,
                    the script searches the current directory and ~/Downloads.

Examples:
  $(basename "$0") ~/Downloads/Antigravity-linux-x64.tar.gz
  $(basename "$0") --system
  $(basename "$0") --user ./antigravity.tar.gz
EOF
}

# --- Argument Parsing ---
INSTALL_SCOPE=""
UNINSTALL_MODE=false
ARCHIVE_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)
            INSTALL_SCOPE="system"
            shift
            ;;
        --user)
            INSTALL_SCOPE="user"
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$ARCHIVE_PATH" ]]; then
                ARCHIVE_PATH="$1"
            else
                log_error "Unexpected extra argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# --- Helper: Run with sudo if system scope ---
run_cmd() {
    if [[ "$INSTALL_SCOPE" == "system" && "$EUID" -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# --- Prompt for Installation Scope if not specified ---
select_scope() {
    if [[ -n "$INSTALL_SCOPE" ]]; then
        return
    fi

    echo -e "${BOLD}Select installation target:${RESET}"
    echo "  1) System-wide (/opt/antigravity) [Requires sudo]"
    echo "  2) User-only   ($HOME/Applications/antigravity)"
    echo ""
    while true; do
        read -rp "Enter choice [1 or 2] (default: 1): " choice
        case "${choice:-1}" in
            1) INSTALL_SCOPE="system"; break ;;
            2) INSTALL_SCOPE="user"; break ;;
            *) echo "Please enter 1 or 2." ;;
        esac
    done
}

# --- Uninstall Routine ---
perform_uninstall() {
    select_scope

    if [[ "$INSTALL_SCOPE" == "system" ]]; then
        TARGET_DIR="/opt/antigravity"
        BIN_LINK="/usr/local/bin/antigravity"
        DESKTOP_FILE="/usr/share/applications/antigravity.desktop"
        ICON_FILE="/usr/share/icons/hicolor/512x512/apps/antigravity.png"
        APPARMOR_PROFILE="/etc/apparmor.d/antigravity"
    else
        TARGET_DIR="$HOME/Applications/antigravity"
        BIN_LINK="$HOME/.local/bin/antigravity"
        DESKTOP_FILE="$HOME/.local/share/applications/antigravity.desktop"
        ICON_FILE="$HOME/.local/share/icons/hicolor/512x512/apps/antigravity.png"
        APPARMOR_PROFILE=""
    fi

    log_info "Uninstalling Antigravity ($INSTALL_SCOPE)..."

    [[ -d "$TARGET_DIR" ]] && run_cmd rm -rf "$TARGET_DIR" && log_success "Removed $TARGET_DIR"
    [[ -L "$BIN_LINK" || -f "$BIN_LINK" ]] && run_cmd rm -f "$BIN_LINK" && log_success "Removed $BIN_LINK"
    [[ -f "$DESKTOP_FILE" ]] && run_cmd rm -f "$DESKTOP_FILE" && log_success "Removed $DESKTOP_FILE"
    [[ -f "$ICON_FILE" ]] && run_cmd rm -f "$ICON_FILE" && log_success "Removed $ICON_FILE"

    if [[ -n "$APPARMOR_PROFILE" && -f "$APPARMOR_PROFILE" ]]; then
        run_cmd rm -f "$APPARMOR_PROFILE"
        run_cmd systemctl reload apparmor 2>/dev/null || true
        log_success "Removed AppArmor profile"
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        if [[ "$INSTALL_SCOPE" == "system" ]]; then
            run_cmd update-desktop-database /usr/share/applications 2>/dev/null || true
        else
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        fi
    fi

    log_success "Antigravity has been completely removed."
    exit 0
}

if [[ "$UNINSTALL_MODE" == true ]]; then
    perform_uninstall
fi

# --- Locate the .tar.gz Archive ---
find_archive() {
    if [[ -n "$ARCHIVE_PATH" ]]; then
        if [[ ! -f "$ARCHIVE_PATH" ]]; then
            log_error "Specified file does not exist: $ARCHIVE_PATH"
            exit 1
        fi
        ARCHIVE_PATH="$(realpath "$ARCHIVE_PATH")"
        return
    fi

    log_info "No archive path provided. Searching current directory and ~/Downloads..."

    # Search for case-insensitive *antigravity*.tar.gz in . and ~/Downloads
    mapfile -t FOUND_FILES < <(find . "$HOME/Downloads" -maxdepth 1 -type f -iname "*antigravity*.tar.gz" 2>/dev/null | sort -r)

    if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then
        log_error "Could not find any '*antigravity*.tar.gz' file in $(pwd) or $HOME/Downloads."
        echo "Please pass the path explicitly: ./$(basename "$0") /path/to/antigravity.tar.gz"
        exit 1
    elif [[ ${#FOUND_FILES[@]} -eq 1 ]]; then
        ARCHIVE_PATH="$(realpath "${FOUND_FILES[0]}")"
        log_info "Found archive: ${CYAN}$ARCHIVE_PATH${RESET}"
    else
        echo -e "${BOLD}Multiple Antigravity archives found:${RESET}"
        for i in "${!FOUND_FILES[@]}"; do
            echo "  $((i + 1))) ${FOUND_FILES[$i]}"
        done
        while true; do
            read -rp "Select archive [1-${#FOUND_FILES[@]}]: " file_idx
            if [[ "$file_idx" =~ ^[0-9]+$ ]] && (( file_idx >= 1 && file_idx <= ${#FOUND_FILES[@]} )); then
                ARCHIVE_PATH="$(realpath "${FOUND_FILES[$((file_idx - 1))]}")"
                break
            fi
            echo "Invalid selection."
        done
    fi
}

# --- Main Installation Routine ---
main() {
    echo -e "${BOLD}${CYAN}=== Antigravity Community Installer ===${RESET}"

    find_archive
    select_scope

    # Configure target paths based on scope
    if [[ "$INSTALL_SCOPE" == "system" ]]; then
        INSTALL_DIR="/opt/antigravity"
        BIN_DIR="/usr/local/bin"
        APP_DIR="/usr/share/applications"
        ICON_DIR="/usr/share/icons/hicolor/512x512/apps"
    else
        INSTALL_DIR="$HOME/Applications/antigravity"
        BIN_DIR="$HOME/.local/bin"
        APP_DIR="$HOME/.local/share/applications"
        ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
    fi

    log_info "Archive:     $ARCHIVE_PATH"
    log_info "Destination: $INSTALL_DIR"
    log_info "Scope:       $INSTALL_SCOPE"

    # Create temporary extraction directory and ensure cleanup on exit
    TMP_DIR="$(mktemp -d -t antigravity-install-XXXXXX)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    log_info "Extracting archive to temporary directory..."
    tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

    # Detect whether the tarball extracted into a single top-level folder or flat files
    EXTRACTED_ITEMS=("$TMP_DIR"/*)
    if [[ ${#EXTRACTED_ITEMS[@]} -eq 1 && -d "${EXTRACTED_ITEMS[0]}" ]]; then
        SOURCE_DIR="${EXTRACTED_ITEMS[0]}"
    else
        SOURCE_DIR="$TMP_DIR"
    fi

    # Locate the main executable inside the extracted contents
    EXEC_CANDIDATE=""
    if [[ -f "$SOURCE_DIR/antigravity" ]]; then
        EXEC_CANDIDATE="antigravity"
    elif [[ -f "$SOURCE_DIR/Antigravity" ]]; then
        EXEC_CANDIDATE="Antigravity"
    else
        # Fallback: find first executable file at root of extracted folder
        FOUND_EXEC="$(find "$SOURCE_DIR" -maxdepth 1 -type f -executable | head -n 1)"
        if [[ -n "$FOUND_EXEC" ]]; then
            EXEC_CANDIDATE="$(basename "$FOUND_EXEC")"
        else
            log_error "Could not identify the main Antigravity binary inside the archive."
            exit 1
        fi
    fi
    log_info "Detected binary: $EXEC_CANDIDATE"

    # Prepare destination directory (clean upgrade if already installed)
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warn "Existing installation found at $INSTALL_DIR. Replacing..."
        run_cmd rm -rf "$INSTALL_DIR"
    fi

    run_cmd mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APP_DIR" "$ICON_DIR"

    log_info "Copying files to $INSTALL_DIR..."
    run_cmd cp -a "$SOURCE_DIR"/. "$INSTALL_DIR"/
    run_cmd chmod +x "$INSTALL_DIR/$EXEC_CANDIDATE"

    # Create CLI Symlink
    log_info "Creating CLI symlink at $BIN_DIR/antigravity..."
    run_cmd ln -sf "$INSTALL_DIR/$EXEC_CANDIDATE" "$BIN_DIR/antigravity"

    # Locate application icon (PNG or SVG)
    ICON_SOURCE="$(find "$INSTALL_DIR" -maxdepth 4 -type f \( -iname "*antigravity*.png" -o -iname "icon.png" -o -iname "app.png" \) | head -n 1)"
    ICON_VALUE="antigravity"

    if [[ -n "$ICON_SOURCE" ]]; then
        log_info "Installing application icon..."
        run_cmd cp "$ICON_SOURCE" "$ICON_DIR/antigravity.png"
    else
        log_warn "No PNG icon found in archive; using fallback icon reference."
        ICON_VALUE="utilities-terminal"
    fi

    # Ubuntu 24.04 / 26.04 LTS Electron/Chromium Sandbox Handling
    # Ubuntu restricts unprivileged user namespaces via AppArmor. If chrome-sandbox exists,
    # configure an AppArmor profile (for system installs) or setuid permissions.
    if [[ -f "$INSTALL_DIR/chrome-sandbox" ]]; then
        if [[ "$INSTALL_SCOPE" == "system" ]]; then
            log_info "Configuring AppArmor profile for Ubuntu 26.04 LTS sandbox compatibility..."
            APPARMOR_FILE="/etc/apparmor.d/antigravity"
            cat <<EOF | run_cmd tee "$APPARMOR_FILE" >/dev/null
# AppArmor profile for Antigravity to allow unprivileged user namespaces on Ubuntu
abi <abi/4.0>,
include <tunables/global>

profile antigravity "$INSTALL_DIR/$EXEC_CANDIDATE" flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/antigravity>
}
EOF
            run_cmd systemctl reload apparmor 2>/dev/null || true
        else
            log_warn "User-level install detected: if Antigravity fails to launch due to Ubuntu 26.04 AppArmor userns restrictions, run with '--system' or launch with '--no-sandbox'."
        fi
    fi

    # Create .desktop entry for GNOME / Ubuntu App Launcher
    log_info "Registering desktop entry at $APP_DIR/antigravity.desktop..."
    cat <<EOF | run_cmd tee "$APP_DIR/antigravity.desktop" >/dev/null
[Desktop Entry]
Name=Antigravity
Comment=Antigravity IDE / Editor
GenericName=Text Editor
Exec=$INSTALL_DIR/$EXEC_CANDIDATE --new-window %F
Icon=$ICON_VALUE
Type=Application
StartupNotify=true
StartupWMClass=Antigravity
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;
Keywords=antigravity;code;editor;ide;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$INSTALL_DIR/$EXEC_CANDIDATE --new-window %F
Icon=$ICON_VALUE
EOF

    run_cmd chmod 644 "$APP_DIR/antigravity.desktop"

    # Refresh desktop & icon caches
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database "$APP_DIR" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ "$INSTALL_SCOPE" == "system" ]]; then
        run_cmd gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    fi

    echo ""
    log_success "Antigravity installed successfully!"
    echo -e "  • ${BOLD}Install Path:${RESET} $INSTALL_DIR"
    echo -e "  • ${BOLD}CLI Command:${RESET}  antigravity"

    # Check if ~/.local/bin is in PATH for user installs
    if [[ "$INSTALL_SCOPE" == "user" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo ""
        log_warn "$HOME/.local/bin is not currently in your PATH."
        echo "  Add it by running: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    fi
}

main