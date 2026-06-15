#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# reset.sh — reset demo state between customer sessions
# Clears Xray findings, wipes seeded packages, re-runs prep.sh
#
# Usage:
#   ./setup/reset.sh          # full reset + re-seed
#   ./setup/reset.sh --wipe   # wipe only (no re-seed)
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found"; exit 1; }

PREFIX="${JFROG_PROJECT_KEY:+${JFROG_PROJECT_KEY}-}${JFROG_REPO_PREFIX:-demo}"
MODE="${1:-all}"

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip — Demo reset                      ║"
echo "╚══════════════════════════════════════════════╝"
echo "  This will wipe all artifacts from demo repos."
echo "  Instance: $JFROG_URL / Prefix: $PREFIX"
echo
read -rp "  Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo
echo "▶  Deleting artifacts from dev repos..."
for PKG in maven npm pypi docker go nuget helm gradle; do
  REPO="${PREFIX}-${PKG}-dev"
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -X DELETE "$JFROG_URL/artifactory/$REPO/" 2>/dev/null && \
    echo "  ✅  Cleared $REPO" || \
    echo "  ⚠️  Could not clear $REPO (may be empty)"
done

echo
echo "▶  Clearing Xray scan cache for demo repos..."
curl -s -o /dev/null \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JFROG_URL/xray/api/v1/index/artifactory/reindex" \
  -d "{\"repo_name\": \"${PREFIX}-npm-dev\"}" 2>/dev/null && \
  echo "  ✅  Xray reindex triggered" || true

if [[ "$MODE" != "--wipe" ]]; then
  echo
  echo "▶  Re-seeding demo data..."
  "$SCRIPT_DIR/prep.sh"
fi

echo
echo "  ✅  Reset complete — ready for next demo session"
