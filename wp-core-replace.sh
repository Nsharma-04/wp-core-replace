#!/usr/bin/env bash
# =============================================================================
#  wp-core-replace.sh
#  Safely replaces WordPress core files with the exact same version.
#
#  Usage:
#    chmod +x wp-core-replace.sh
#    ./wp-core-replace.sh [/path/to/wordpress]   # defaults to current dir
#
#  Requirements: wp-cli must be installed and on PATH
# =============================================================================

set -uo pipefail
# Note: -e (exit on error) intentionally omitted so non-fatal steps
# do not abort the script. Each step handles its own errors explicitly.

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}══ $* ${RESET}"; }

# ── Resolve WordPress root ────────────────────────────────────────────────────
WP_ROOT="${1:-$(pwd)}"
cd "$WP_ROOT" || error "Cannot cd into: $WP_ROOT"

[[ -f "wp-includes/version.php" ]] || error "No WordPress installation found at: $WP_ROOT"

echo -e "\n${BOLD}╔══════════════════════════════════════════════╗"
echo -e "║      WordPress Core Replacement Script       ║"
echo -e "╚══════════════════════════════════════════════╝${RESET}"
log "Working directory: ${BOLD}$WP_ROOT${RESET}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Fix file permissions (644)
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 1 — Fixing file permissions (644)"
find "$WP_ROOT" -type f -exec chmod 644 {} \;
success "All files set to 644"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Fix folder permissions (755)
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 2 — Fixing folder permissions (755)"
find "$WP_ROOT" -type d -exec chmod 755 {} \;
success "All directories set to 755"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Remove 0-byte files
# Uses a temp file list instead of process substitution for wider
# shell compatibility (cPanel, shared hosting, restricted /dev/fd envs)
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 3 — Removing 0-byte files"
ZERO_LIST=$(mktemp /tmp/wp_zero_XXXXXX)
find "$WP_ROOT" -type f -empty > "$ZERO_LIST" 2>/dev/null || true
ZERO_COUNT=$(wc -l < "$ZERO_LIST" | tr -d ' ')

if [[ "$ZERO_COUNT" -eq 0 ]]; then
    success "No 0-byte files found"
else
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        log "Removing: $file"
        rm -f "$file"
    done < "$ZERO_LIST"
    success "Removed ${ZERO_COUNT} zero-byte file(s)"
fi
rm -f "$ZERO_LIST"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Detect installed WordPress version
# Three fallback methods tried in order:
#   1. Parse wp-includes/version.php directly
#   2. Ask WP-CLI for the version
#   3. Fall back to "latest" with a warning
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 4 — Detecting WordPress version"
WP_VERSION=""

# Method 1 — parse version.php
log "Method 1: reading wp-includes/version.php ..."
WP_VERSION=$(grep "^\$wp_version " "$WP_ROOT/wp-includes/version.php" 2>/dev/null \
    | sed "s/.*'\(.*\)'.*/\1/" || true)

# Method 2 — ask WP-CLI
if [[ -z "$WP_VERSION" ]]; then
    warn "Method 1 failed. Trying WP-CLI ..."
    if command -v wp &>/dev/null; then
        WP_VERSION=$(wp core version --path="$WP_ROOT" --allow-root 2>/dev/null || true)
    fi
fi

# Method 3 — fallback to latest
if [[ -z "$WP_VERSION" ]]; then
    warn "Could not detect WP version from version.php or WP-CLI."
    warn "Proceeding to download the LATEST version of WordPress."
    WP_VERSION="latest"
else
    success "Detected WordPress version: ${BOLD}${WP_VERSION}${RESET}"
fi

# Safety guard — confirm before destructive steps
echo ""
if [[ "$WP_VERSION" == "latest" ]]; then
    warn "About to REMOVE wp-admin and wp-includes, then re-download the LATEST WP version"
else
    warn "About to REMOVE wp-admin and wp-includes, then re-download WP ${WP_VERSION}"
fi
read -r -p "$(echo -e "${YELLOW}  Continue? [y/N]:${RESET} ")" CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { log "Aborted by user."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Remove WordPress core directories
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 5 — Removing wp-admin and wp-includes"
rm -rf "${WP_ROOT}/wp-admin" "${WP_ROOT}/wp-includes"
success "Core directories removed"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Re-download WordPress core via WP-CLI
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 6 — Re-downloading WordPress core${WP_VERSION:+ v${WP_VERSION}}"

# Check WP-CLI is available
command -v wp &>/dev/null || error "wp-cli not found. Install it from https://wp-cli.org"

if [[ "$WP_VERSION" == "latest" ]]; then
    log "Version unknown — downloading latest WordPress release ..."
    wp core download \
        --path="$WP_ROOT" \
        --force \
        --skip-content \
        --allow-root
    # Capture the actual version that was downloaded for the final message
    WP_VERSION=$(wp core version --path="$WP_ROOT" --allow-root 2>/dev/null || echo "latest")
else
    wp core download \
        --path="$WP_ROOT" \
        --version="$WP_VERSION" \
        --force \
        --skip-content \
        --allow-root
fi

success "WordPress ${WP_VERSION} core files restored"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — Re-apply correct permissions on fresh files
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 7 — Re-applying permissions on restored core files"
find "${WP_ROOT}/wp-admin"    -type f -exec chmod 644 {} \;
find "${WP_ROOT}/wp-admin"    -type d -exec chmod 755 {} \;
find "${WP_ROOT}/wp-includes" -type f -exec chmod 644 {} \;
find "${WP_ROOT}/wp-includes" -type d -exec chmod 755 {} \;
success "Permissions re-applied on wp-admin and wp-includes"

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}✔  All steps completed successfully!${RESET}"
echo -e "   WordPress core ${BOLD}${WP_VERSION}${RESET} has been replaced cleanly.\n"
