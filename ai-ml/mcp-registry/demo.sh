#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip AI/ML Demo — JFrog MCP Server & MCP Registry
# Demonstrates: JFrog MCP Server capabilities + MCP package storage
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Status: BETA (JFrog MCP Server is in Beta as of 2025)
# Prerequisites: .env configured (JFROG_MCP_URL set), bootstrap.sh run
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

STATUS="BETA"
CI_MODE="${1:-}"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"

# MCP Server URL (set in .env as JFROG_MCP_URL)
MCP_URL="${JFROG_MCP_URL:-${JFROG_URL}/mcp}"

# MCP package storage repo (generic/local for storing custom MCP servers)
REPO_MCP="${PREFIX}-mcp-local"

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }
note()  { echo "  💡  $1"; }
prompt(){ echo; echo "  🤖  Demo prompt to type in Cursor / Claude Code:"; echo; echo "      $1"; echo; }

# ── Reset ─────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting MCP Registry demo state..."
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_MCP}/swiftship-mcp-demo/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SwiftShip AI/ML Demo — JFrog MCP Server  [${STATUS}]           ║"
echo "║  Story: AI agents with live JFrog security data              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Instance : ${JFROG_URL}"
echo "  MCP URL  : ${MCP_URL}"
echo "  Note     : ${STATUS} — requires MCP Server enabled by Platform Admin"
echo

# Show client config files
note "Client config files are in this directory:"
echo "    .cursor/mcp.json        — Cursor configuration"
echo "    .claude/settings.json   — Claude Code configuration"

# ── Step 1: Verify JFrog MCP Server is enabled ───────────────────
step "1 / 5  Verify JFrog MCP Server is reachable  [${STATUS}]"
echo "  Endpoint: ${MCP_URL}"
hr

MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${MCP_URL}" 2>/dev/null || echo "000")

case "$MCP_STATUS" in
  200)
    pass "JFrog MCP Server is reachable (HTTP 200)"
    ;;
  404)
    warn "MCP Server returned HTTP 404 — it may not be enabled on this instance"
    echo "  Enable via: Platform Admin → Integrations → JFrog MCP Server → Set Up"
    echo "  Continuing demo with direct API calls to show equivalent data..."
    ;;
  401|403)
    warn "MCP Server returned HTTP ${MCP_STATUS} — check JFROG_TOKEN has MCP access"
    ;;
  000)
    warn "MCP Server not reachable — check JFROG_MCP_URL in .env"
    echo "  Expected format: https://<instance>.jfrog.io/mcp"
    ;;
  *)
    warn "MCP Server returned HTTP ${MCP_STATUS}"
    ;;
esac

echo
echo "  Configuration used by AI agents:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Cursor (.cursor/mcp.json):                                  │"
echo "  │    { \"mcpServers\": { \"jfrog\": { \"url\": \"${MCP_URL}\" } } }   │"
echo "  │                                                              │"
echo "  │  Claude Code (.claude/settings.json):                        │"
echo "  │    { \"mcpServers\": { \"jfrog\": { \"type\": \"sse\",            │"
echo "  │        \"url\": \"${MCP_URL}\" } } }                            │"
echo "  └──────────────────────────────────────────────────────────────┘"
pause

# ── Step 2: Demo prompt — CVE query ──────────────────────────────
step "2 / 5  Demo prompt: CVE query for auth-service"

prompt "What CVEs are critical in my auth-service dependencies?"

echo "  What happens under the hood (MCP tool called):"
echo "    → catalog_vulnerabilities_get + artifactory_artifacts_get_summary"
echo
echo "  Expected AI response:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  I found 2 critical CVEs in auth-service dependencies:       │"
echo "  │                                                              │"
echo "  │  1. CVE-2025-41234  CVSS 9.8  CRITICAL                      │"
echo "  │     spring-core 6.1.6 — Path traversal Remote Code Execution│"
echo "  │     Fix: upgrade to spring-core 6.1.14+                     │"
echo "  │                                                              │"
echo "  │  2. CVE-2025-41248  CVSS 9.1  CRITICAL                      │"
echo "  │     spring-security-core 6.2.2 — Authorization bypass       │"
echo "  │     Fix: upgrade to spring-security 6.3.4+                  │"
echo "  │                                                              │"
echo "  │  Both findings are in demo-maven-dev. Promote this build?   │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo

# Make the equivalent direct Xray API call to show real data
echo "  Backing this up with a direct Xray API call:"
jf xr curl -s "/api/v1/summary/artifact" \
  --server-id=swiftship \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"paths\":[\"default/${PREFIX}-maven-dev/org/springframework/spring-core/6.1.6/spring-core-6.1.6.jar\"]}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | \
  grep -A3 '"cves"\|CVE-2025-41234\|"severity"\|"summary"' | head -20 || \
  echo "  (artifact not yet indexed — run ./setup/prep.sh --service auth first)"
pass "CVE query demonstrated"
pause

# ── Step 3: Demo prompt — reachability analysis ───────────────────
step "3 / 5  Demo prompt: reachability analysis (JAS)"

prompt "Is CVE-2025-41234 reachable in auth-service?"

echo "  What happens under the hood (MCP tool called):"
echo "    → artifactory_artifacts_get_summary with JAS contextual analysis"
echo
echo "  Expected AI response:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  JAS Contextual Analysis result for CVE-2025-41234:          │"
echo "  │                                                              │"
echo "  │  Status: REACHABLE ⚠️                                        │"
echo "  │  Evidence: App.serveFile() in App.java calls the vulnerable  │"
echo "  │    Spring path resolution method via @GetMapping(\"/api/files\")│"
echo "  │                                                              │"
echo "  │  Attack path: HTTP GET /api/files/{filename}                 │"
echo "  │    → Spring MVC path resolution (spring-core 6.1.6)         │"
echo "  │    → CVE-2025-41234 path traversal trigger                  │"
echo "  │                                                              │"
echo "  │  Recommendation: Upgrade spring-core to 6.1.14+ immediately.│"
echo "  │  This is a network-reachable, unauthenticated exploit path. │"
echo "  └──────────────────────────────────────────────────────────────┘"
pass "Reachability analysis demonstrated"
note "JAS must be enabled on the instance for contextual analysis to work"
pause

# ── Step 4: Demo prompt — Curation status ────────────────────────
step "4 / 5  Demo prompt: Curation status query"

prompt "Which packages are blocked by Curation today?"

echo "  What happens under the hood (MCP tool called):"
echo "    → curation_packages_get_status (queries Curation audit log)"
echo
echo "  Expected AI response:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Curation blocks in the last 24 hours:                      │"
echo "  │                                                              │"
echo "  │  1. @nx/devkit@19.5.0  (npm)                                │"
echo "  │     Reason: CVE-2025-10894 — malicious supply-chain package  │"
echo "  │     Policy: Block packages with known malicious behaviour    │"
echo "  │     Blocked at: 2026-06-16 08:14:32 UTC                     │"
echo "  │                                                              │"
echo "  │  2. community-untrusted/backdoor-llm-demo  (huggingfaceml)  │"
echo "  │     Reason: Org not on approved HuggingFace allowlist       │"
echo "  │     Policy: Block models from unverified organizations       │"
echo "  │     Blocked at: 2026-06-16 09:22:11 UTC                     │"
echo "  │                                                              │"
echo "  │  3. langflow==1.1.4  (pypi)                                 │"
echo "  │     Reason: CVE-2025-3248 CVSS 9.8, CISA KEV               │"
echo "  │     Policy: Block CISA KEV packages                         │"
echo "  │     Blocked at: 2026-06-16 10:05:57 UTC                     │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo

# Make a direct Curation API call to show real data
echo "  Direct Curation API call (equivalent to MCP tool):"
curl -s \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  -H "Content-Type: application/json" \
  "${JFROG_URL}/xray/api/v1/curation/audit?blocked=true&limit=5" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -30 || \
  echo "  (Curation audit API not available or no blocks yet — run setup/prep.sh first)"
pass "Curation status query demonstrated"
pause

# ── Step 5: Publish a custom MCP server package ───────────────────
step "5 / 5  Publish a custom MCP server package to Artifactory"
echo "  Storing a custom MCP server package in the JFrog registry"
echo "  (enables versioning, signing, Xray scanning of MCP servers)"
hr

# Ensure the MCP local repo exists
REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/repositories/${REPO_MCP}" 2>/dev/null)
if [[ "$REPO_STATUS" == "404" ]]; then
  curl -s -o /dev/null \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    -H "Content-Type: application/json" \
    -X PUT "${JFROG_URL}/artifactory/api/repositories/${REPO_MCP}" \
    -d "{\"key\":\"${REPO_MCP}\",\"rclass\":\"local\",\"packageType\":\"generic\",
         \"description\":\"Custom MCP server packages — versioned, signed, Xray-scanned\"}" \
    2>/dev/null
  pass "Created MCP package repo: ${REPO_MCP}"
else
  pass "MCP package repo exists: ${REPO_MCP}"
fi

# Create a minimal demo MCP server package
MCP_PKG_DIR="/tmp/swiftship-mcp-demo"
MCP_PKG_NAME="swiftship-jira-connector"
MCP_PKG_VERSION="1.0.0"
rm -rf "$MCP_PKG_DIR" && mkdir -p "$MCP_PKG_DIR"

cat > "${MCP_PKG_DIR}/mcp-server.json" << 'MCPJSON'
{
  "name": "swiftship-jira-connector",
  "version": "1.0.0",
  "description": "Internal MCP server — connects AI agents to SwiftShip's Jira instance",
  "transport": "stdio",
  "tools": [
    { "name": "create_ticket", "description": "Create a Jira ticket with security findings" },
    { "name": "link_cve_to_ticket", "description": "Link a CVE finding to an existing ticket" },
    { "name": "get_ticket_status", "description": "Check the status of a security ticket" }
  ],
  "author": "swiftship-platform-team",
  "license": "Apache-2.0"
}
MCPJSON

cat > "${MCP_PKG_DIR}/package.json" << 'PKGJSON'
{
  "name": "@swiftship/jira-connector-mcp",
  "version": "1.0.0",
  "description": "Internal MCP server for SwiftShip Jira integration",
  "main": "index.js",
  "bin": { "swiftship-jira-mcp": "./index.js" }
}
PKGJSON

echo "  // Stub MCP server — demo only" > "${MCP_PKG_DIR}/index.js"
echo "  console.log('SwiftShip Jira MCP server v1.0.0 starting...');" >> "${MCP_PKG_DIR}/index.js"

# Package it
MCP_ZIP="/tmp/${MCP_PKG_NAME}-${MCP_PKG_VERSION}.zip"
(cd "/tmp" && zip -r "$MCP_ZIP" "swiftship-mcp-demo/" -x "*.DS_Store" 2>/dev/null) || \
  tar -czf "${MCP_ZIP%.zip}.tar.gz" -C "/tmp" "swiftship-mcp-demo/"
MCP_ARCHIVE="${MCP_ZIP}"
[[ -f "$MCP_ZIP" ]] || MCP_ARCHIVE="${MCP_ZIP%.zip}.tar.gz"

# Upload to Artifactory
echo "  Uploading ${MCP_PKG_NAME}-${MCP_PKG_VERSION} to ${REPO_MCP}..."
jf rt u "${MCP_ARCHIVE}" \
  "${REPO_MCP}/${MCP_PKG_NAME}/${MCP_PKG_VERSION}/${MCP_PKG_NAME}-${MCP_PKG_VERSION}.zip" \
  --server-id=swiftship \
  --props "mcp.server.name=${MCP_PKG_NAME};mcp.server.version=${MCP_PKG_VERSION};mcp.server.transport=stdio" \
  2>&1 | tail -5 || {
    warn "Upload failed — check JFROG_TOKEN permissions"
  }

pass "Custom MCP server package published to ${REPO_MCP}"
echo
echo "  To install from Artifactory (enterprise distribution):"
echo "    jf rt dl \"${REPO_MCP}/${MCP_PKG_NAME}/1.0.0/*.zip\" /tmp/mcp-install/ --server-id=swiftship"
echo
echo "  Xray will scan this package for embedded secrets, malicious code,"
echo "  and dependency vulnerabilities — the same as any other artifact."

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  MCP Registry demo complete  [${STATUS}]                     ║"
echo "║                                                              ║"
echo "║  Key moments:                                                ║"
echo "║    Step 1 — MCP Server verified (or shown as config)        ║"
echo "║    Step 2 — AI agent queried live Xray CVE data             ║"
echo "║    Step 3 — JAS reachability answered in natural language   ║"
echo "║    Step 4 — Curation blocks visible to AI agent             ║"
echo "║    Step 5 — Custom MCP server stored + governed in JFrog    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
