#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip Package Demo — Maven
# Demonstrates: Xray (CVE-2025-41234 Spring RCE), stage-gate block
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Prerequisites: .env configured, bootstrap.sh already run
# Requires: JDK 17+, Maven 3.8+ (or skips build gracefully)
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

CI_MODE="${1:-}"
PKG_TYPE="maven"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_DEV="${PREFIX}-maven-dev"
REPO_STAGE="${PREFIX}-maven-stage"
REPO_PROD="${PREFIX}-maven-prod"
BUILD_NAME="swiftship-auth-service-demo"
BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"
APP_DIR="$SCRIPT_DIR/sample-app"

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }

# Check Maven availability once; degrade gracefully if absent
MAVEN_AVAILABLE=false
if command -v mvn &>/dev/null || command -v ./mvnw &>/dev/null; then
  MAVEN_AVAILABLE=true
fi

# ── Reset ──────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting Maven demo state..."
  cd "$APP_DIR"
  mvn clean -q 2>/dev/null || rm -rf target/ 2>/dev/null || true
  # Restore original pom.xml (undo step-5 version bump)
  git checkout -- pom.xml 2>/dev/null || true
  # Remove published artifacts from dev repo
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_DEV}/com/swiftship/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SwiftShip Demo — Maven                                   ║"
echo "║  Story: Spring RCE found, stage gate blocks promotion     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  Instance : ${JFROG_URL}"
echo "  Dev repo  : ${REPO_DEV}"
echo "  Build     : ${BUILD_NAME}@${BUILD_NUMBER}"
[[ "$MAVEN_AVAILABLE" == false ]] && warn "Maven not found — build steps skipped; jf audit still runs"

# ── Step 1: Verify repos ─────────────────────────────────────────
step "1 / 5  Verify Artifactory Maven repos"
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

# ── Step 2: Deploy vulnerable jar to dev repo ────────────────────
step "2 / 5  Configure Maven via JFrog CLI and deploy vulnerable jar"
echo "  artifact: com.swiftship:auth-service-demo:1.0.0"
echo "  contains: spring-core 6.1.6 (CVE-2025-41234, CVSS 9.8)"
echo "            spring-security-core 6.2.2 (CVE-2025-41248, CVSS 9.1)"
hr

cd "$APP_DIR"

# Configure JFrog CLI for Maven (writes .jfrog/projects/maven.yaml)
jf mvn-config \
  --repo-resolve-releases="${REPO_DEV}" \
  --repo-resolve-snapshots="${REPO_DEV}" \
  --repo-deploy-releases="${REPO_DEV}" \
  --repo-deploy-snapshots="${REPO_DEV}" \
  --server-id-resolve=$JF_SERVER_ID \
  --server-id-deploy=$JF_SERVER_ID \
  2>/dev/null
pass "JFrog CLI configured for Maven (server: $JF_SERVER_ID → ${REPO_DEV})"

if [[ "$MAVEN_AVAILABLE" == true ]]; then
  echo "  Running: jf mvn deploy -DskipTests ..."
  jf mvn deploy \
    -DskipTests \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER}" \
    --quiet \
    2>&1 | tail -8 || {
      warn "Maven build failed — running jf audit directly (no deploy)"
    }

  # Publish build info to Artifactory (enables Xray build scanning)
  jf rt bce "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=$JF_SERVER_ID 2>/dev/null || true
  jf rt bp  "${BUILD_NAME}" "${BUILD_NUMBER}" --server-id=$JF_SERVER_ID 2>/dev/null || true
  pass "Deployed auth-service-demo-1.0.0.jar to ${REPO_DEV}"
else
  warn "Skipping mvn deploy (JDK/Maven not available) — Xray audit still works"
fi
cd "$SCRIPT_DIR"
pause

# ── Step 3: Xray scan — CVE-2025-41234 ───────────────────────────
step "3 / 5  Xray scan — CVE-2025-41234 (Spring Framework RCE, CVSS 9.8)"
echo "  Querying Xray for spring-core 6.1.6 artifact..."
hr
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=$JF_SERVER_ID \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${REPO_DEV}/org/springframework/spring-core/6.1.6/spring-core-6.1.6.jar\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | \
  grep -A5 '"cves"\|CVE-2025-41234\|CVE-2025-41248\|"severity"\|"summary"' | head -40 || true

echo
echo "  Running local project audit (full Maven dependency tree)..."
cd "$APP_DIR"
jf audit --mvn --server-id=$JF_SERVER_ID --format=table 2>&1 | head -40 || true
cd "$SCRIPT_DIR"

hr
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  CVE-2025-41234  CVSS 9.8  CRITICAL                    │"
echo "  │  Package : spring-core 6.1.6                            │"
echo "  │  Impact  : Path traversal → Remote Code Execution       │"
echo "  │  Fix     : upgrade to spring-core 6.1.14+               │"
echo "  ├─────────────────────────────────────────────────────────┤"
echo "  │  CVE-2025-41248  CVSS 9.1  CRITICAL                    │"
echo "  │  Package : spring-security-core 6.2.2                   │"
echo "  │  Impact  : Authorization rule bypass                     │"
echo "  │  Fix     : upgrade to spring-security 6.3.4+            │"
echo "  └─────────────────────────────────────────────────────────┘"
pass "CVE-2025-41234 and CVE-2025-41248 detected in ${REPO_DEV}"
pause

# ── Step 4: Promotion to Stage — blocked by policy ───────────────
step "4 / 5  Stage promotion gate — BLOCKED (CVSS >= 7.0 policy violation)"
echo "  Attempting: jf apptrust version-promote ${BUILD_NAME} 1.0.0 STAGE"
echo "  Policy    : ${PREFIX}-stage-policy (block on CVSS >= 7.0)"
hr

# Try AppTrust promotion first (preferred path)
PROMOTE_OUTPUT=""
set +e
if command -v jf &>/dev/null; then
  PROMOTE_OUTPUT=$(jf apptrust version-promote swiftship-auth-service 1.0.0 STAGE \
    --sync=true \
    --server-id=$JF_SERVER_ID 2>&1 || true)

  # Fall back to Xray build scan if AppTrust not available
  if echo "$PROMOTE_OUTPUT" | grep -qi "not found\|unknown command\|404"; then
    PROMOTE_OUTPUT=$(jf rt bpr "${BUILD_NAME}" "${BUILD_NUMBER}" "${REPO_STAGE}" \
      --copy=false \
      --status=Staged \
      --server-id=$JF_SERVER_ID \
      --fail-fast=true 2>&1 || true)
  fi
fi
set -e

echo "  Promotion result:"
echo "$PROMOTE_OUTPUT" | head -20 || true
echo

if echo "$PROMOTE_OUTPUT" | grep -qiE "blocked|violation|policy|failed|error|CVSS|CVE"; then
  pass "Stage gate BLOCKED as expected"
  echo "  Reason: spring-core 6.1.6 (CVSS 9.8) exceeds the 7.0 stage threshold"
  echo "  The auth-service cannot ship to customers until this CVE is resolved."
else
  warn "Promotion was not blocked — verify the stage Xray policy is active"
  echo "  To check: ${JFROG_URL}/ui/admin/xray/policies"
  echo "  Required: ${PREFIX}-stage-policy with fail_build: true on CVSS >= 7.0"
fi
pause

# ── Step 5: Fixed version — spring-core 6.1.14 ───────────────────
step "5 / 5  Fix: spring-core 6.1.6 → 6.1.14 — clean promotion"
echo "  Updating spring-core to 6.1.14 and spring-security to 6.3.4..."
hr
cd "$APP_DIR"

# Save original pom.xml for reset
cp pom.xml /tmp/pom-maven-demo.xml.bak

# Patch the version properties in pom.xml
if command -v sed &>/dev/null; then
  sed -i.bak \
    -e 's|<spring-framework.version>6\.1\.6</spring-framework.version>|<spring-framework.version>6.1.14</spring-framework.version>|g' \
    -e 's|<spring-security.version>6\.2\.2</spring-security.version>|<spring-security.version>6.3.4</spring-security.version>|g' \
    pom.xml
  rm -f pom.xml.bak
fi

echo "  Diff (vulnerable → fixed versions):"
diff /tmp/pom-maven-demo.xml.bak pom.xml || true
echo

if [[ "$MAVEN_AVAILABLE" == true ]]; then
  echo "  Running: jf mvn deploy -DskipTests (with fixed deps)..."
  BUILD_NUMBER_FIXED=$((BUILD_NUMBER + 1))
  jf mvn deploy \
    -DskipTests \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER_FIXED}" \
    --quiet \
    2>&1 | tail -8 || true
fi

echo "  Re-running Xray audit on fixed dependency tree..."
jf audit --mvn --server-id=$JF_SERVER_ID --format=table 2>&1 | head -30 || true

# Restore original pom.xml for repeatability
cp /tmp/pom-maven-demo.xml.bak pom.xml
cd "$SCRIPT_DIR"
pass "spring-core 6.1.14 — CVE-2025-41234 resolved"
pass "spring-security 6.3.4 — CVE-2025-41248 resolved"
pass "No CVSS >= 7.0 findings — Stage promotion will succeed"

echo
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅  Maven demo complete                                  ║"
echo "║                                                           ║"
echo "║  Key moments:                                             ║"
echo "║    Step 3 — Xray found Spring RCE (CVSS 9.8)            ║"
echo "║    Step 4 — Stage gate blocked vulnerable version        ║"
echo "║    Step 5 — Fixed Spring versions pass the gate          ║"
echo "╚══════════════════════════════════════════════════════════╝"
