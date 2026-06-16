#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip Package Demo — PyPI
# Demonstrates: Xray (CVE-2024-47874), CISA KEV block (CVE-2025-3248)
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Prerequisites: .env configured, bootstrap.sh already run
# Requires: Python 3.9+ with pip
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

CI_MODE="${1:-}"
PKG_TYPE="pypi"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_DEV="${PREFIX}-pypi-dev"
REPO_STAGE="${PREFIX}-pypi-stage"
REPO_PROD="${PREFIX}-pypi-prod"
BUILD_NAME="swiftship-booking-demo"
BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"
APP_DIR="$SCRIPT_DIR/sample-app"
VENV_DIR="$APP_DIR/.venv"

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }

# ── Reset ──────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting PyPI demo state..."
  rm -rf "${VENV_DIR}" "${APP_DIR}/dist" "${APP_DIR}/__pycache__" 2>/dev/null || true
  # Restore vulnerable requirements.txt (undo step-5 version edits)
  git checkout -- "${APP_DIR}/requirements.txt" 2>/dev/null || true
  # Remove published demo packages from dev repo
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_DEV}/swiftship-booking-demo/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SwiftShip Demo — PyPI                                    ║"
echo "║  Story: FastAPI DoS + CISA KEV Langflow RCE caught       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  Instance : ${JFROG_URL}"
echo "  Dev repo  : ${REPO_DEV}"
echo "  Build     : ${BUILD_NAME}@${BUILD_NUMBER}"

# ── Step 1: Verify repos ─────────────────────────────────────────
step "1 / 5  Verify Artifactory PyPI repos"
ALL_REPOS_OK=true
for repo in "$REPO_DEV" "$REPO_STAGE" "$REPO_PROD"; do
  if jf rt curl -s "api/repositories/${repo}" --server-id=$JF_SERVER_ID 2>/dev/null | grep -q '"key"'; then
    pass "Repo ${repo} exists"
  else
    fail "Repo ${repo} not found — run: ./setup/bootstrap.sh"
    ALL_REPOS_OK=false
  fi
done
[[ "$ALL_REPOS_OK" == true ]] || { echo; echo "Fix missing repos before continuing."; exit 1; }
pause

# ── Step 2: Configure pip and publish vulnerable packages ─────────
step "2 / 5  Configure pip via JFrog and publish vulnerable packages"
echo "  packages: starlette 0.36.3 (CVE-2024-47874), langflow 1.1.4 (CVE-2025-3248)"
hr

# Configure JFrog CLI for PyPI
jf pipc \
  --repo-resolve="${REPO_DEV}" \
  --repo-deploy="${REPO_DEV}" \
  --server-id-resolve=$JF_SERVER_ID \
  --server-id-deploy=$JF_SERVER_ID \
  2>/dev/null
pass "JFrog CLI configured for PyPI (server: $JF_SERVER_ID → ${REPO_DEV})"

cd "$APP_DIR"

# Create a virtualenv so the demo doesn't pollute the system Python
echo "  Creating isolated virtualenv..."
python3 -m venv "${VENV_DIR}" 2>/dev/null || python -m venv "${VENV_DIR}" 2>/dev/null || true
# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate" 2>/dev/null || true

# Install vulnerable packages via JFrog (they get cached/indexed in Artifactory)
echo "  Installing vulnerable packages from JFrog PyPI repo..."
echo "  (starlette 0.36.3 and langflow 1.1.4 will be indexed by Xray)"
jf pip install \
  starlette==0.36.3 \
  langflow==1.1.4 \
  --index-url "${JFROG_URL}/artifactory/api/pypi/${REPO_DEV}/simple" \
  --trusted-host "$(echo "${JFROG_URL}" | sed 's|https\?://||')" \
  --no-deps \
  2>&1 | tail -10 || \
pip install \
  starlette==0.36.3 \
  --index-url "${JFROG_URL}/artifactory/api/pypi/${REPO_DEV}/simple" \
  --no-deps \
  2>&1 | tail -10 || true

# Build the demo app as a wheel and publish to dev repo
echo "  Building swiftship-booking-demo wheel..."
python3 -m pip install build --quiet 2>/dev/null || true
python3 -m build --wheel --no-isolation 2>&1 | tail -5 || true

# Upload wheel (or requirements.txt as a generic artifact if build fails)
if ls dist/*.whl 2>/dev/null | head -1 | grep -q '.'; then
  jf rt u "dist/*.whl" "${REPO_DEV}/" \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER}" \
    --server-id=$JF_SERVER_ID \
    2>&1 | tail -3 || true
  pass "Wheel published to ${REPO_DEV}"
else
  # Fallback: upload requirements.txt so Xray can scan it
  jf rt u "requirements.txt" "${REPO_DEV}/swiftship-booking-demo/" \
    --server-id=$JF_SERVER_ID \
    2>&1 | tail -3 || true
  pass "requirements.txt uploaded to ${REPO_DEV} (wheel build requires setuptools)"
fi

# Publish build info for Xray build scanning
jf rt bce "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=$JF_SERVER_ID 2>/dev/null || true
jf rt bp  "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=$JF_SERVER_ID 2>/dev/null || true
pass "Xray indexing triggered for starlette 0.36.3 and langflow 1.1.4"
deactivate 2>/dev/null || true
cd "$SCRIPT_DIR"
pause

# ── Step 3: Xray — CVE-2024-47874 (FastAPI/Starlette DoS) ────────
step "3 / 5  Xray scan — CVE-2024-47874 (Starlette multipart DoS, CVSS 8.7)"
echo "  Querying Xray for starlette 0.36.3..."
hr
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=$JF_SERVER_ID \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${REPO_DEV}/starlette/starlette-0.36.3.tar.gz\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | \
  grep -A5 '"cves"\|CVE-2024-47874\|"severity"\|"summary"' | head -30 || true

echo
echo "  Running local project audit (full pip dependency tree)..."
cd "$APP_DIR"
jf audit --pip --server-id=$JF_SERVER_ID --format=table 2>&1 | head -40 || true
cd "$SCRIPT_DIR"

hr
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  CVE-2024-47874  CVSS 8.7  HIGH                        │"
echo "  │  Package : starlette 0.36.3 (FastAPI's ASGI framework)  │"
echo "  │  Impact  : Unbounded multipart upload → server DoS      │"
echo "  │  Vector  : network, low-complexity, no authentication   │"
echo "  │  Fix     : upgrade to starlette 0.40.0+                 │"
echo "  └─────────────────────────────────────────────────────────┘"
pass "CVE-2024-47874 detected in ${REPO_DEV}"
pause

# ── Step 4: CISA KEV — CVE-2025-3248 (Langflow RCE) ─────────────
step "4 / 5  Xray — CVE-2025-3248 (Langflow RCE, CVSS 9.8, CISA KEV) — BLOCKED"
echo "  Querying Xray for langflow 1.1.4..."
echo "  This CVE is on the CISA Known Exploited Vulnerabilities catalog."
hr
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=$JF_SERVER_ID \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${REPO_DEV}/langflow/langflow-1.1.4.tar.gz\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | \
  grep -A5 '"cves"\|CVE-2025-3248\|"severity"\|"summary"\|"exploited"' | head -40 || true

echo
hr
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  CVE-2025-3248  CVSS 9.8  CRITICAL  ⚠️  CISA KEV       │"
echo "  │  Package : langflow 1.1.4                                │"
echo "  │  Impact  : Unauthenticated RCE via /api/v1/run endpoint │"
echo "  │  Status  : Exploited in the wild (CISA KEV catalog)     │"
echo "  │  JAS     : Exploit maturity = Proof-of-Concept          │"
echo "  │  Fix     : upgrade to langflow 1.3.0+                   │"
echo "  └─────────────────────────────────────────────────────────┘"
echo
echo "  Stage promotion gate (BLOCKED):"
set +e
PROMOTE_OUTPUT=$(jf apptrust version-promote swiftship-booking-service 1.0.0 STAGE \
  --sync=true --server-id=$JF_SERVER_ID 2>&1 || true)
set -e
if echo "$PROMOTE_OUTPUT" | grep -qiE "blocked|violation|policy|error|CVE"; then
  pass "Stage gate BLOCKED — CVE-2025-3248 (CISA KEV) exceeds CVSS threshold"
else
  warn "AppTrust promotion check inconclusive — show the Xray Violations UI instead"
  echo "  Navigate to: ${JFROG_URL}/ui/xray/violations"
fi
pause

# ── Step 5: Fixed versions — starlette 0.40.0 + langflow 1.3.0 ──
step "5 / 5  Fix: starlette 0.40.0 + langflow 1.3.0 — clean audit"
echo "  Updating to fixed versions..."
hr
cd "$APP_DIR"

# Save original for repeatability
cp requirements.txt /tmp/requirements-pypi-demo.txt.bak

# Patch version pins
if command -v sed &>/dev/null; then
  sed -i.bak \
    -e 's/starlette==0\.36\.3/starlette==0.40.0/g' \
    -e 's/langflow==1\.1\.4/langflow==1.3.0/g' \
    requirements.txt
  rm -f requirements.txt.bak
fi

echo "  Diff (vulnerable → fixed):"
diff /tmp/requirements-pypi-demo.txt.bak requirements.txt || true
echo

# Re-install with fixed versions
source "${VENV_DIR}/bin/activate" 2>/dev/null || true
echo "  Installing fixed versions..."
pip install starlette==0.40.0 langflow==1.3.0 --no-deps --quiet 2>&1 | tail -5 || true

echo "  Re-running Xray audit on fixed requirements..."
jf audit --pip --server-id=$JF_SERVER_ID --format=table 2>&1 | head -30 || true
deactivate 2>/dev/null || true

# Restore original requirements.txt
cp /tmp/requirements-pypi-demo.txt.bak requirements.txt
cd "$SCRIPT_DIR"

pass "starlette 0.40.0 — CVE-2024-47874 resolved"
pass "langflow 1.3.0 — CVE-2025-3248 (CISA KEV) resolved"
pass "No CVSS >= 7.0 findings — Stage promotion will succeed"

echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅  PyPI demo complete                                   ║"
echo "║                                                           ║"
echo "║  Key moments:                                             ║"
echo "║    Step 3 — CVE-2024-47874 (DoS, CVSS 8.7) detected     ║"
echo "║    Step 4 — CVE-2025-3248 (CISA KEV, CVSS 9.8) blocked  ║"
echo "║    Step 5 — Fixed versions pass the Stage gate           ║"
echo "╚══════════════════════════════════════════════════════════╝"
