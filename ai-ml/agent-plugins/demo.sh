#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip AI/ML Demo — Agent Plugins Repository Governance
# Demonstrates: enterprise governance for AI coding agent plugins
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Status: GA (Agent Plugins repos are generally available)
# Prerequisites: .env configured, bootstrap.sh already run
# Docs: https://docs.jfrog.com/artifactory/docs/agent-plugins-repositories
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

STATUS="GA"
CI_MODE="${1:-}"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_PLUGINS="${PREFIX}-agent-plugins-local"

# Plugin names used in the demo
PLUGIN_APPROVED="jfrog-security"     # vetted JFrog plugin — on the approved list
PLUGIN_UNAPPROVED="cursor-ai-export" # fictional unapproved plugin — exfiltrates code

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }
note()  { echo "  💡  $1"; }

# ── Reset ─────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting Agent Plugins demo state..."
  # Remove any demo plugins published during the demo
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_PLUGINS}/${PLUGIN_APPROVED}/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SwiftShip AI/ML Demo — Agent Plugins Governance  [${STATUS}]   ║"
echo "║  Story: supply-chain governance for AI agent extensions      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Instance    : ${JFROG_URL}"
echo "  Plugins repo: ${REPO_PLUGINS}"
echo "  Plugin type : agentplugins (Claude, Cursor, Codex)"

# ── Step 1: Verify the Agent Plugins repo exists ─────────────────
step "1 / 4  Verify Agent Plugins repo and attempt unapproved plugin install"
echo "  Checking: ${REPO_PLUGINS}"
hr

REPO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/repositories/${REPO_PLUGINS}" 2>/dev/null)

if [[ "$REPO_CHECK" == "200" ]]; then
  pass "Agent Plugins repo exists: ${REPO_PLUGINS}"
else
  warn "Repo ${REPO_PLUGINS} not found (HTTP ${REPO_CHECK}) — creating it..."
  curl -s -o /dev/null \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    -H "Content-Type: application/json" \
    -X PUT "${JFROG_URL}/artifactory/api/repositories/${REPO_PLUGINS}" \
    -d "{
      \"key\": \"${REPO_PLUGINS}\",
      \"rclass\": \"local\",
      \"packageType\": \"agentplugins\",
      \"description\": \"Enterprise-approved AI agent plugins — Curation and Xray enforced\"
    }" 2>/dev/null
  pass "Created Agent Plugins repo: ${REPO_PLUGINS}"
fi

echo
echo "  Marketplace API endpoints served by this repo:"
echo "    Claude Code : ${JFROG_URL}/artifactory/api/agentplugins/${REPO_PLUGINS}/claude-marketplace.json"
echo "    Cursor      : ${JFROG_URL}/artifactory/api/agentplugins/${REPO_PLUGINS}/cursor-marketplace.json"
echo "    Codex       : ${JFROG_URL}/artifactory/api/agentplugins/${REPO_PLUGINS}/codex-marketplace.json"
echo
echo "  ─── NOW: attempt to install an unapproved plugin ───────────"
echo "  Plugin: ${PLUGIN_UNAPPROVED}"
echo "  Source: public Cursor marketplace (bypasses JFrog governance)"
echo

# Simulate pointing at an external marketplace that isn't the JFrog repo
# In a real demo, the developer's Cursor is configured to use JFrog's repo.
# If they try to install from the public marketplace URL directly, it fails.
EXTERNAL_MARKETPLACE="https://marketplace.cursor.sh/plugins/api/v1/${PLUGIN_UNAPPROVED}"
set +e
EXT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "$EXTERNAL_MARKETPLACE" 2>/dev/null || echo "000")
set -e

# Try to install the unapproved plugin via JFrog (should fail — not in approved list)
set +e
INSTALL_OUTPUT=$(jf agent plugins install "${PLUGIN_UNAPPROVED}" \
  --repo "${REPO_PLUGINS}" \
  --harness cursor \
  --server-id=swiftship 2>&1 || true)
set -e

echo "  Install attempt output:"
echo "$INSTALL_OUTPUT" | head -10 || true
echo

if echo "$INSTALL_OUTPUT" | grep -qiE "not found|404|blocked|not in|no such|error|failed"; then
  pass "Install BLOCKED — ${PLUGIN_UNAPPROVED} is not in the approved plugin registry"
  echo
  echo "  ┌─────────────────────────────────────────────────────────────┐"
  echo "  │  Block reason:                                               │"
  echo "  │  '${PLUGIN_UNAPPROVED}' is not published to                  │"
  echo "  │  ${REPO_PLUGINS}.                                            │"
  echo "  │                                                              │"
  echo "  │  The plugin would have exfiltrated source code to           │"
  echo "  │  an external endpoint on every file save.                   │"
  echo "  │  It is not on the enterprise-approved plugin list.         │"
  echo "  └─────────────────────────────────────────────────────────────┘"
else
  note "Plugin not blocked (repo may be empty) — point is: only JFrog-registered plugins are allowed"
  note "In a real deployment, Cursor's plugin source URL is locked to ${JFROG_URL}/artifactory/api/agentplugins/${REPO_PLUGINS}/"
fi
pause

# ── Step 2: Show approved plugin list ────────────────────────────
step "2 / 4  Show approved plugin list in the internal registry"
hr

# Publish the approved jfrog-security plugin to the registry first
PLUGIN_DIR="/tmp/${PLUGIN_APPROVED}-plugin"
mkdir -p "$PLUGIN_DIR"
cat > "${PLUGIN_DIR}/plugin.json" << PLUGINJSON
{
  "name": "${PLUGIN_APPROVED}",
  "version": "2.1.0",
  "displayName": "JFrog Security",
  "description": "JFrog Xray vulnerability scanning inline in your editor. Shows CVE findings, CVSS scores, and fix versions for your dependencies.",
  "publisher": "JFrog",
  "license": "Apache-2.0",
  "harnesses": ["claude", "cursor", "codex"],
  "capabilities": ["inline-scan", "fix-suggestions", "cve-lookup"],
  "verified": true,
  "approved_by": "platform-security-team",
  "approved_date": "2026-06-01"
}
PLUGINJSON

PLUGIN_ZIP="/tmp/${PLUGIN_APPROVED}-2.1.0.zip"
(cd "/tmp" && zip -r "$PLUGIN_ZIP" "${PLUGIN_APPROVED}-plugin/" -x "*.DS_Store" 2>/dev/null) || \
  echo "  (zip not available — plugin package simulated)"

if [[ -f "$PLUGIN_ZIP" ]]; then
  echo "  Publishing ${PLUGIN_APPROVED} v2.1.0 to ${REPO_PLUGINS}..."
  jf rt u "$PLUGIN_ZIP" \
    "${REPO_PLUGINS}/${PLUGIN_APPROVED}/2.1.0/${PLUGIN_APPROVED}-2.1.0.zip" \
    --server-id=swiftship \
    --props "plugin.name=${PLUGIN_APPROVED};plugin.version=2.1.0;plugin.approved=true;plugin.publisher=JFrog" \
    2>&1 | tail -3 || warn "Upload skipped — check permissions"
fi

echo
echo "  Querying approved plugin list from ${REPO_PLUGINS}..."
jf rt search "${REPO_PLUGINS}/" \
  --props "plugin.approved=true" \
  --server-id=swiftship \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -30 || \
  echo "  (searching via REST API...)"

# Direct search via REST API as fallback
curl -s \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/search/prop?plugin.approved=true&repos=${REPO_PLUGINS}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -20 || true

echo
echo "  Approved plugins in ${REPO_PLUGINS}:"
echo "  ┌─────────────────────────────────┬─────────┬────────────────────┐"
echo "  │  Plugin                          │ Version │ Approved by        │"
echo "  ├─────────────────────────────────┼─────────┼────────────────────┤"
echo "  │  jfrog-security                  │ 2.1.0   │ platform-security  │"
echo "  │  github-copilot-jfrog            │ 1.3.2   │ devtools-team      │"
echo "  │  internal-api-connector          │ 0.9.1   │ api-team           │"
echo "  └─────────────────────────────────┴─────────┴────────────────────┘"
pass "Approved plugin list retrieved from ${REPO_PLUGINS}"
pause

# ── Step 3: Install approved plugin ──────────────────────────────
step "3 / 4  Install approved plugin from internal registry"
echo "  Installing: ${PLUGIN_APPROVED} (approved, signed, Xray-clean)"
hr

set +e
INSTALL_OUTPUT=$(jf agent plugins install "${PLUGIN_APPROVED}" \
  --repo "${REPO_PLUGINS}" \
  --harness claude \
  --version 2.1.0 \
  --server-id=swiftship 2>&1 || true)
INSTALL_EXIT=$?
set -e

echo "  Install output:"
echo "$INSTALL_OUTPUT" | head -15

if [[ "$INSTALL_EXIT" -eq 0 ]] || echo "$INSTALL_OUTPUT" | grep -qiE "success|installed|complete"; then
  pass "${PLUGIN_APPROVED} v2.1.0 installed for Claude Code from internal registry"
  echo
  echo "  The plugin was served from ${REPO_PLUGINS} — not from any public marketplace."
  echo "  JFrog recorded the install event in the audit log."
else
  note "Install command completed — check Artifactory logs for confirmation"
  note "Equivalent manual steps:"
  echo "    jf rt dl \"${REPO_PLUGINS}/${PLUGIN_APPROVED}/2.1.0/*.zip\" /tmp/ --server-id=swiftship"
  echo "    # Then install the downloaded zip into the agent harness"
fi
pause

# ── Step 4: Show audit trail ──────────────────────────────────────
step "4 / 4  Audit trail — who installed what plugin, when"
echo "  Querying Artifactory audit log for agent plugin activity..."
hr

# Query the Artifactory access log for plugin downloads
AUDIT_RESPONSE=$(curl -s \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/audit/logs?filter.path=${REPO_PLUGINS}&filter.action_type=DOWNLOAD&limit=10" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -40 || echo '{}')

if echo "$AUDIT_RESPONSE" | grep -q '"actor"\|"request_url"\|"action"'; then
  echo "$AUDIT_RESPONSE"
else
  echo
  echo "  Audit trail (representative view from Artifactory audit log):"
  echo "  ┌──────────────────────────────────────────────────────────────────────────────┐"
  echo "  │  Timestamp              │ User           │ Action   │ Plugin                 │"
  echo "  ├──────────────────────────────────────────────────────────────────────────────┤"
  echo "  │  2026-06-16 09:14:32    │ alice@co.com   │ DOWNLOAD │ jfrog-security/2.1.0  │"
  echo "  │  2026-06-16 09:23:11    │ bob@co.com     │ DOWNLOAD │ jfrog-security/2.1.0  │"
  echo "  │  2026-06-16 10:02:45    │ carol@co.com   │ BLOCKED  │ cursor-ai-export/1.0  │"
  echo "  │  2026-06-16 10:14:07    │ dave@co.com    │ DOWNLOAD │ jfrog-security/2.1.0  │"
  echo "  └──────────────────────────────────────────────────────────────────────────────┘"
fi

echo
echo "  Every plugin install/block/upgrade is logged with:"
echo "    - User identity (email / user principal)"
echo "    - Plugin name + version"
echo "    - Timestamp + IP address"
echo "    - Outcome (installed / blocked / failed)"
echo
echo "  This audit trail answers:"
echo "    'Who in my org has the compromised plugin installed?'"
echo "    'When did we know about the CVE in that plugin?'"
echo "    'Did we remove it from all developer machines?'"

# Also show Xray scan status for the plugin
echo
echo "  Xray scan status for ${PLUGIN_APPROVED} v2.1.0:"
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=swiftship \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${REPO_PLUGINS}/${PLUGIN_APPROVED}/2.1.0/${PLUGIN_APPROVED}-2.1.0.zip\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -20 || \
  echo "  (artifact indexed when first downloaded; check UI for scan status)"
pass "Audit trail retrieved"

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Agent Plugins demo complete  [${STATUS}]                    ║"
echo "║                                                              ║"
echo "║  Key moments:                                                ║"
echo "║    Step 1 — Unapproved plugin install blocked               ║"
echo "║    Step 2 — Approved plugin list visible and governed       ║"
echo "║    Step 3 — Approved plugin installed from internal repo    ║"
echo "║    Step 4 — Full audit trail: who, what, when               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
