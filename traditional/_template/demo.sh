#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip Package Demo — REPLACE_PACKAGE_TYPE
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Prerequisites: .env configured, bootstrap.sh already run
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

CI_MODE="${1:-}"
PKG_TYPE="REPLACE_PACKAGE_TYPE"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"

# Repo names (namespaced if project key set)
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_DEV="${PREFIX}-${PKG_TYPE}-dev"
REPO_STAGE="${PREFIX}-${PKG_TYPE}-stage"
REPO_PROD="${PREFIX}-${PKG_TYPE}-prod"

# ── Helpers ─────────────────────────────────────────────────────
step() { echo; echo "━━━ $1"; }
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; read -rp "  Press Enter to continue..."; }

# ── Reset ────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting $PKG_TYPE demo state..."
  # REPLACE: add package-specific reset commands here
  echo "✓ Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip Demo — $PKG_TYPE"
echo "╚══════════════════════════════════════════════╝"

step "1 / 5  Verify Artifactory repos exist"
for repo in "$REPO_DEV" "$REPO_STAGE" "$REPO_PROD"; do
  if jf rt curl -s "api/repositories/$repo" --server-id=swiftship | grep -q '"key"'; then
    pass "Repo $repo exists"
  else
    fail "Repo $repo not found — did you run setup/bootstrap.sh?"
  fi
done
pause

step "2 / 5  Upload a vulnerable package to dev repo"
# REPLACE: add package-type-specific upload command
# Example: jf rt u "sample-app/target/*.jar" "$REPO_DEV/" --server-id=swiftship
echo "  (replace this with package-specific upload)"
pause

step "3 / 5  Trigger Xray scan and show findings"
jf xr curl -s "api/v1/summary/artifact" \
  --server-id=swiftship \
  -d "{\"paths\":[\"default/$REPO_DEV/REPLACE_ARTIFACT_PATH\"]}" \
  -H "Content-Type: application/json" | python3 -m json.tool || true
pause

step "4 / 5  Attempt promotion to stage (should be blocked by policy)"
# REPLACE: add promotion command
echo "  (replace this with package-specific promotion)"
pause

step "5 / 5  Show fixed version — clean promotion to stage"
# REPLACE: show the fixed version passing
echo "  (replace this with fixed version demo)"

echo
echo "✅  $PKG_TYPE demo complete"
