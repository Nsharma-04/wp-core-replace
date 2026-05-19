# wp-core-replace

> Cleans infected WordPress sites — fixes permissions, removes 0-byte files, and replaces core files with a fresh copy of the exact same version.

---

## When to use this

Use this script when your WordPress site gets infected by malware or a hack attack. Compromised sites often end up with broken file & folder permissions, hundreds of 0-byte ghost files injected across the installation, and corrupted or tampered core files. This script automatically corrects all file permissions to `644` and folder permissions to `755`, wipes out every 0-byte file left behind by the attack, detects your exact WordPress version, removes the compromised `wp-admin` and `wp-includes` directories, and re-downloads a clean copy of the same WordPress core version using WP-CLI — without touching your theme, plugins, uploads, or `wp-config.php`. Run it any time your site behaves unexpectedly after an infection and you need a fast, reliable core reset.

---

## What it does

| Step | Action |
|------|--------|
| 1 | Fix all **file** permissions → `644` |
| 2 | Fix all **folder** permissions → `755` |
| 3 | Delete all **0-byte files** left by the attack |
| 4 | Auto-detect installed **WP version** from `wp-includes/version.php` |
| 5 | Remove compromised `wp-admin` and `wp-includes` |
| 6 | Re-download the exact same version via WP-CLI (`--skip-content`) |
| 7 | Re-apply correct permissions on restored core files |

> Your `wp-content/`, `wp-config.php`, and all other custom files are **never touched**.

---

## Requirements

- Linux / macOS (bash 4+)
- [WP-CLI](https://wp-cli.org/) installed and available on `$PATH`

---

## Usage

### Option A — One-liner (fastest, no files left behind)

```bash
curl -s https://raw.githubusercontent.com/Nsharma-04/wp-core-replace/main/wp-core-replace.sh | bash
```

### Option B — Pass the WordPress path directly

```bash
curl -s https://raw.githubusercontent.com/Nsharma-04/wp-core-replace/main/wp-core-replace.sh -o /tmp/wp-fix.sh \
  && chmod +x /tmp/wp-fix.sh \
  && /tmp/wp-fix.sh /var/www/html/yoursite
```

### Option C — Clone and run locally

```bash
git clone https://github.com/Nsharma-04/wp-core-replace.git /tmp/wp-core-replace
chmod +x /tmp/wp-core-replace/wp-core-replace.sh
/tmp/wp-core-replace/wp-core-replace.sh /var/www/html/yoursite
```

### Option D — Pull latest and re-run (multi-site workflow)

```bash
cd /tmp/wp-core-replace
git pull origin main
./wp-core-replace.sh /var/www/html/yoursite
```

> **Tip:** Always use the `raw.githubusercontent.com` URL, not the `github.com/blob/` URL — the blob URL returns an HTML page, not the script.

---

## Example output

```
╔══════════════════════════════════════════════╗
║      WordPress Core Replacement Script       ║
╚══════════════════════════════════════════════╝
[INFO]  Working directory: /var/www/html/mysite

══ STEP 1 — Fixing file permissions (644)
[OK]    All files set to 644

══ STEP 2 — Fixing folder permissions (755)
[OK]    All directories set to 755

══ STEP 3 — Removing 0-byte files
[OK]    Removed 3 zero-byte file(s)

══ STEP 4 — Detecting WordPress version
[OK]    Detected WordPress version: 6.5.3

[WARN]  About to REMOVE wp-admin and wp-includes, then re-download WP 6.5.3
  Continue? [y/N]: y

══ STEP 5 — Removing wp-admin and wp-includes
[OK]    Core directories removed

══ STEP 6 — Re-downloading WordPress core v6.5.3
[OK]    WordPress 6.5.3 core files restored

══ STEP 7 — Re-applying permissions on restored core files
[OK]    Permissions re-applied on wp-admin and wp-includes

✔  All steps completed successfully!
   WordPress core 6.5.3 has been replaced cleanly.
```

---

## License

MIT
