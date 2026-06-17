#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# prep.sh — night-before demo preparation
# Seeds all SwiftShip services with vulnerable packages so
# findings are ready to show. Run this the evening before a demo.
#
# Dependency resolution is configured via .jfrog/projects/ YAML files
# in each service directory — no manual jf *-config calls needed.
# The CLI picks up the YAML automatically on cd into the directory.
#
# Usage:
#   ./setup/prep.sh                      # seed everything
#   ./setup/prep.sh --service auth       # seed one service only
#   ./setup/prep.sh --dry-run            # show what would be done
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found"; exit 1; }

SERVICE_FILTER="${2:-all}"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

step()  { echo; echo "▶  $1"; }
ok()    { echo "   ✅  $1"; }
dry()   { echo "   [dry-run] $1"; }
run()   { $DRY_RUN && dry "$*" || eval "$@"; }

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip — Night-before prep               ║"
echo "╚══════════════════════════════════════════════╝"
echo "  Instance:  $JFROG_URL"
echo "  Server ID: $JF_SERVER_ID"
echo "  Dry run:   $DRY_RUN"

# Configure JFrog CLI server
step "Configuring JFrog CLI"
run jf config add "$JF_SERVER_ID" \
  --url="$JFROG_URL" \
  --access-token="$JFROG_TOKEN" \
  --interactive=false \
  --overwrite 2>/dev/null || true
ok "JFrog CLI configured (server: $JF_SERVER_ID)"

# ── Maven / auth-service ─────────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "auth" ]]; then
  step "Seeding auth-service (Maven — CVE-2025-41234, CVE-2025-41248)"
  cd "$ROOT_DIR/e2e/swiftship/auth-service"
  # .jfrog/projects/maven.yaml routes resolution through Artifactory
  run jf mvn package -DskipTests --quiet 2>/dev/null || \
    echo "   (Maven build skipped — requires JDK 17. jf audit will still scan.)"
  run jf audit --mvn --server-id=$JF_SERVER_ID || true
  ok "auth-service Maven scan triggered"
  cd "$ROOT_DIR"
fi

# ── npm / storefront-ui ──────────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "storefront" ]]; then
  step "Seeding storefront-ui (npm — CVE-2024-21538, Shai-Hulud CVE-2025-10894)"
  cd "$ROOT_DIR/e2e/swiftship/storefront-ui"
  # .jfrog/projects/npm.yaml routes install through Artifactory
  run jf npm install --no-fund --no-audit 2>&1 | tail -5 || true
  run jf audit --npm --server-id=$JF_SERVER_ID || true
  ok "storefront-ui npm scan triggered"
  cd "$ROOT_DIR"
fi

# ── PyPI / booking-service ───────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "booking" ]]; then
  step "Seeding booking-service (PyPI — CVE-2024-47874, CVE-2025-3248)"
  cd "$ROOT_DIR/e2e/swiftship/booking-service"
  # .jfrog/projects/pip.yaml routes install through Artifactory
  run jf pip install -r requirements.txt --no-deps 2>&1 | tail -5 || true
  run jf audit --pip --server-id=$JF_SERVER_ID || true
  ok "booking-service PyPI scan triggered"
  cd "$ROOT_DIR"
fi

# ── NuGet / payments-service ─────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "payments" ]]; then
  step "Seeding payments-service (NuGet — CVE-2024-21907, AGPL license)"
  cd "$ROOT_DIR/e2e/swiftship/payments-service"
  # .jfrog/projects/nuget.yaml routes resolution through Artifactory
  run jf audit --nuget --server-id=$JF_SERVER_ID || true
  ok "payments-service NuGet scan triggered"
  cd "$ROOT_DIR"
fi

# ── Go / logistics-service ───────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "logistics" ]]; then
  step "Seeding logistics-service (Go — CVE-2025-22869, CVE-2025-22871)"
  cd "$ROOT_DIR/e2e/swiftship/logistics-service"
  # .jfrog/projects/go.yaml routes resolution through Artifactory
  run jf go mod tidy 2>&1 | tail -5 || true
  run jf audit --go --server-id=$JF_SERVER_ID || true
  ok "logistics-service Go scan triggered"
  cd "$ROOT_DIR"
fi

# ── PyPI / recommendation-engine ─────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "recommendation" ]]; then
  step "Seeding recommendation-engine (PyPI — CVE-2025-3248)"
  cd "$ROOT_DIR/e2e/swiftship/recommendation-engine"
  # .jfrog/projects/pip.yaml routes install through Artifactory
  run jf pip install -r requirements.txt --no-deps 2>&1 | tail -5 || true
  run jf audit --pip --server-id=$JF_SERVER_ID || true
  ok "recommendation-engine PyPI scan triggered"
  cd "$ROOT_DIR"
fi

# ── Helm / infra ─────────────────────────────────────────────────
if [[ "$SERVICE_FILTER" == "all" || "$SERVICE_FILTER" == "infra" ]]; then
  step "Seeding infra Helm chart (IaC misconfiguration + secrets)"
  run jf audit --iac --secrets --server-id=$JF_SERVER_ID \
    --working-dirs="$ROOT_DIR/e2e/swiftship/infra" || true
  ok "infra Helm JAS IaC + secrets scan triggered"
fi

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅  Prep complete — you're demo-ready       ║"
echo "║                                              ║"
echo "║  Next: ./setup/validate.sh                   ║"
echo "╚══════════════════════════════════════════════╝"
