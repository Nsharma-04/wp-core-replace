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

set -euo pipefail

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
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 3 — Removing 0-byte files"
ZERO_COUNT=0
while IFS= read -r -d '' file; do
    log "Removing: $file"
    rm -f "$file"
    (( ZERO_COUNT++ )) || true
done < <(find "$WP_ROOT" -type f -empty -print0)

if [[ $ZERO_COUNT -eq 0 ]]; then
    success "No 0-byte files found"
else
    success "Removed ${ZERO_COUNT} zero-byte file(s)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Detect installed WordPress version
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 4 — Detecting WordPress version"
WP_VERSION=$(grep "^\$wp_version " "$WP_ROOT/wp-includes/version.php" \
    | sed "s/.*'\(.*\)'.*/\1/")

[[ -n "$WP_VERSION" ]] || error "Could not detect WP version from version.php"
success "Detected WordPress version: ${BOLD}${WP_VERSION}${RESET}"

# Safety guard — confirm before destructive steps
echo ""
warn "About to REMOVE wp-admin and wp-includes, then re-download WP ${WP_VERSION}"
read -r -p "$(echo -e "${YELLOW}  Continue? [y/N]:${RESET} ")" CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { log "Aborted by user."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Remove WordPress core directories
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 5 — Removing wp-admin and wp-includes"
rm -rf "${WP_ROOT}/wp-admin" "${WP_ROOT}/wp-includes"
success "Core directories removed"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Re-download the exact same WP version via WP-CLI
# ─────────────────────────────────────────────────────────────────────────────
step "STEP 6 — Re-downloading WordPress core v${WP_VERSION}"

# Check WP-CLI is available
command -v wp &>/dev/null || error "wp-cli not found. Install it from https://wp-cli.org"

wp core download \
    --path="$WP_ROOT" \
    --version="$WP_VERSION" \
    --force \
    --skip-content \
    --allow-root

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
