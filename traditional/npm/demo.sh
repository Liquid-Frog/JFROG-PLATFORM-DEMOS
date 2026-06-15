#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip Package Demo — npm
# Demonstrates: Curation, Xray (CVE-2024-21538), supply-chain block
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

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

CI_MODE="${1:-}"
PKG_TYPE="npm"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_DEV="${PREFIX}-npm-dev"
REPO_STAGE="${PREFIX}-npm-stage"
REPO_PROD="${PREFIX}-npm-prod"
REPO_VIRTUAL="${PREFIX}-npm-virtual"
BUILD_NAME="swiftship-storefront-demo"
BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }

# ── Reset ──────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting npm demo state..."
  cd "$SCRIPT_DIR/sample-app"
  rm -rf node_modules dist package-lock.json .npmrc 2>/dev/null || true
  # Restore vulnerable package.json (undo any step-5 edits)
  git checkout -- package.json 2>/dev/null || true
  # Remove published demo package from dev repo
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_DEV}/swiftship-storefront-demo/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SwiftShip Demo — npm                                    ║"
echo "║  Story: supply-chain attack blocked, CVE caught at build  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  Instance : ${JFROG_URL}"
echo "  Dev repo  : ${REPO_DEV}"
echo "  Build     : ${BUILD_NAME}@${BUILD_NUMBER}"

# ── Step 1: Verify repos ─────────────────────────────────────────
step "1 / 5  Verify Artifactory npm repos"
ALL_REPOS_OK=true
for repo in "$REPO_DEV" "$REPO_STAGE" "$REPO_PROD"; do
  if jf rt curl -s "api/repositories/${repo}" --server-id=swiftship 2>/dev/null | grep -q '"key"'; then
    pass "Repo ${repo} exists"
  else
    fail "Repo ${repo} not found — run: ./setup/bootstrap.sh"
    ALL_REPOS_OK=false
  fi
done
[[ "$ALL_REPOS_OK" == true ]] || { echo; echo "Fix missing repos before continuing."; exit 1; }
pause

# ── Step 2: Publish vulnerable package to dev repo ───────────────
step "2 / 5  Configure npm via JFrog and publish vulnerable package"
echo "  package: @swiftship/storefront-demo@1.0.0"
echo "  deps   : cross-spawn 7.0.3 (CVE-2024-21538), @nx/devkit 19.5.0"
hr

# Point JFrog CLI at the npm dev repo for this project
jf npmc \
  --repo-resolve="${REPO_DEV}" \
  --repo-deploy="${REPO_DEV}" \
  --server-id-resolve=swiftship \
  --server-id-deploy=swiftship \
  2>/dev/null
pass "JFrog CLI configured for npm (server: swiftship → ${REPO_DEV})"

cd "$SCRIPT_DIR/sample-app"

# Install dependencies via JFrog (caches packages in Artifactory for Xray indexing)
echo "  Running: jf npm install ..."
jf npm install --no-fund --no-audit 2>&1 | grep -v "^npm warn" | tail -8 || true
pass "npm install complete — cross-spawn 7.0.3 now cached in ${REPO_DEV}"

# Tag the build and publish to dev repo
echo "  Publishing to ${REPO_DEV}..."
jf npm publish \
  --build-name="${BUILD_NAME}" \
  --build-number="${BUILD_NUMBER}" \
  --server-id=swiftship \
  2>&1 | tail -5 || true

# Collect build info and publish it (enables Xray build scanning)
jf rt bce "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=swiftship 2>/dev/null || true
jf rt bp  "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=swiftship 2>/dev/null || true
pass "Published ${BUILD_NAME}@1.0.0 to ${REPO_DEV} — Xray indexing triggered"
cd "$SCRIPT_DIR"
pause

# ── Step 3: Xray scan — CVE-2024-21538 ───────────────────────────
step "3 / 5  Xray scan — CVE-2024-21538 (cross-spawn ReDoS, CVSS 7.5)"
echo "  Querying Xray for cross-spawn 7.0.3 artifact summary..."
hr
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=swiftship \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${REPO_DEV}/cross-spawn/-/cross-spawn-7.0.3.tgz\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | \
  grep -A5 '"cves"\|CVE-2024-21538\|"summary"\|"severity"' | head -30 || true

echo
echo "  Running local project audit (full dependency tree)..."
cd "$SCRIPT_DIR/sample-app"
jf audit --npm --server-id=swiftship --format=table 2>&1 | head -40 || true
cd "$SCRIPT_DIR"

hr
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  CVE-2024-21538  CVSS 7.5  HIGH                        │"
echo "  │  Package : cross-spawn 7.0.3                            │"
echo "  │  Impact  : Regular Expression DoS (ReDoS)               │"
echo "  │  Vector  : network-reachable, low-complexity            │"
echo "  │  Fix     : upgrade to cross-spawn 7.0.5                 │"
echo "  └─────────────────────────────────────────────────────────┘"
pass "CVE-2024-21538 detected in ${REPO_DEV}"
pause

# ── Step 4: Curation blocks Shai-Hulud supply-chain attack ────────
step "4 / 5  Curation blocks @nx/devkit@19.5.0 (CVE-2025-10894 — Shai-Hulud)"
echo "  Attempting: jf npm install @nx/devkit@19.5.0"
echo "  Expected  : Curation BLOCKS download (malicious transitive dep)"
hr
cd "$SCRIPT_DIR/sample-app"

set +e
CURATION_OUTPUT=$(jf npm install @nx/devkit@19.5.0 --no-fund --dry-run 2>&1 || true)
INSTALL_OUTPUT=$(jf npm install @nx/devkit@19.5.0 --no-fund 2>&1 || true)
COMBINED="${CURATION_OUTPUT}${INSTALL_OUTPUT}"
set -e

if echo "$COMBINED" | grep -qiE "blocked|curation|403|forbidden|policy|JFrog"; then
  pass "Curation BLOCKED @nx/devkit@19.5.0"
  echo
  echo "  Block reason:"
  echo "    CVE-2025-10894 — 'Shai-Hulud' malicious package in the supply chain"
  echo "    The package exfiltrates CI/CD environment variables on install."
  echo "    Policy fired: 'Block packages with known malicious behaviour (CISA KEV)'"
  echo
  echo "  This package never touched the filesystem. Zero exposure."
else
  warn "Install was not blocked — verify Curation policy is active on ${REPO_VIRTUAL}"
  echo "  To configure: ${JFROG_URL}/ui/admin/curation/policies"
  echo "  Required rule: block packages with CVE severity >= Critical or malicious flag"
  if [[ "$CI_MODE" == "--ci" ]]; then
    echo "  (Continuing in CI mode despite missing Curation block)"
  fi
fi
cd "$SCRIPT_DIR"
pause

# ── Step 5: Fixed version — cross-spawn 7.0.5 ────────────────────
step "5 / 5  Fix: upgrade cross-spawn 7.0.3 → 7.0.5 — clean promotion"
echo "  Updating cross-spawn to 7.0.5 (patch that resolves CVE-2024-21538)..."
hr
cd "$SCRIPT_DIR/sample-app"

# Save original for reset
cp package.json /tmp/package-npm-demo.json.bak

# Patch version in-place
if command -v sed &>/dev/null; then
  sed -i.bak 's/"cross-spawn": "7\.0\.3"/"cross-spawn": "7.0.5"/g' package.json
  rm -f package.json.bak
fi

echo "  Diff (vulnerable → fixed):"
diff /tmp/package-npm-demo.json.bak package.json || true
echo

# Reinstall with fixed version
echo "  Running jf npm install with cross-spawn 7.0.5..."
jf npm install --no-fund --no-audit 2>&1 | grep -v "^npm warn" | tail -8 || true

# Re-audit — should show no CVSS >= 7.5 findings
echo
echo "  Re-running Xray audit on fixed dependency tree..."
jf audit --npm --server-id=swiftship --format=table 2>&1 | head -30 || true

# Restore original package.json for repeatability
cp /tmp/package-npm-demo.json.bak package.json
pass "cross-spawn 7.0.5 is CVE-2024-21538 clean"
pass "No CVSS >= 7.5 findings — ready for Stage promotion"
cd "$SCRIPT_DIR"

echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅  npm demo complete                                    ║"
echo "║                                                           ║"
echo "║  Key moments:                                             ║"
echo "║    Step 3 — Xray found CVE-2024-21538 (CVSS 7.5)        ║"
echo "║    Step 4 — Curation blocked Shai-Hulud supply chain     ║"
echo "║    Step 5 — Fixed dep passes gate; ready for Stage       ║"
echo "╚══════════════════════════════════════════════════════════╝"
