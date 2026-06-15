#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# validate.sh — run this before every demo session
# Checks: CLI, connectivity, token, repos, IDE config, MCP config
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0; WARN=0

green() { echo "  ✅  $1"; ((PASS++)); }
fail()  { echo "  ❌  $1"; ((FAIL++)); }
warn()  { echo "  ⚠️   $1"; ((WARN++)); }
section(){ echo; echo "── $1 ──────────────────────────────────────"; }

echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip Demo — Pre-flight validation      ║"
echo "╚══════════════════════════════════════════════╝"

# ── Load .env ────────────────────────────────────────────────────
section "Environment"
if [[ -f "$ROOT_DIR/.env" ]]; then
  source "$ROOT_DIR/.env"
  green ".env found and loaded"
else
  fail ".env not found — run: cp .env.example .env && edit it"
  echo; echo "Cannot continue without .env"; exit 1
fi

# Required vars
for var in JFROG_URL JFROG_TOKEN JFROG_USER; do
  if [[ -n "${!var:-}" ]]; then
    green "$var is set"
  else
    fail "$var is not set in .env"
  fi
done

# ── JFrog CLI ────────────────────────────────────────────────────
section "JFrog CLI"
if command -v jf &>/dev/null; then
  JF_VERSION=$(jf --version 2>&1 | head -1)
  green "JFrog CLI found: $JF_VERSION"
  # Check it's v2
  if echo "$JF_VERSION" | grep -qE "^jf version 2"; then
    green "CLI is v2 ✓"
  else
    warn "CLI may not be v2 — recommend upgrading: https://docs.jfrog.com/integrations/docs/download-and-install-the-jfrog-cli"
  fi
else
  fail "JFrog CLI (jf) not found — install: curl -fL https://install-cli.jfrog.io | sh"
fi

# ── JFrog connectivity ───────────────────────────────────────────
section "JFrog Platform connectivity"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  "$JFROG_URL/artifactory/api/system/ping" 2>/dev/null || echo "000")

if [[ "$HTTP_STATUS" == "200" ]]; then
  green "Artifactory reachable and token valid ($JFROG_URL)"
elif [[ "$HTTP_STATUS" == "401" ]]; then
  fail "Artifactory reachable but token invalid (HTTP 401) — generate a new token"
elif [[ "$HTTP_STATUS" == "000" ]]; then
  fail "Cannot reach $JFROG_URL — check network/VPN and JFROG_URL in .env"
else
  fail "Unexpected response from Artifactory (HTTP $HTTP_STATUS)"
fi

# ── Xray ─────────────────────────────────────────────────────────
XRAY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  "$JFROG_URL/xray/api/v1/system/ping" 2>/dev/null || echo "000")
if [[ "$XRAY_STATUS" == "200" ]]; then
  green "Xray reachable"
else
  warn "Xray not responding (HTTP $XRAY_STATUS) — Xray scan demos will not work"
fi

# ── AppTrust ─────────────────────────────────────────────────────
AT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  "$JFROG_URL/apptrust/api/v1/applications" 2>/dev/null || echo "000")
if [[ "$AT_STATUS" == "200" ]]; then
  green "AppTrust reachable"
elif [[ "$AT_STATUS" == "404" ]]; then
  warn "AppTrust not enabled on this instance — AppTrust demos will not work"
else
  warn "AppTrust responded HTTP $AT_STATUS — may not be configured"
fi

# ── Demo repos exist ─────────────────────────────────────────────
section "Demo Artifactory repos"
PREFIX="${JFROG_PROJECT_KEY:+${JFROG_PROJECT_KEY}-}${JFROG_REPO_PREFIX:-demo}"
MISSING_REPOS=0
for pkg in maven npm pypi docker go nuget helm; do
  for env in dev stage prod; do
    REPO="${PREFIX}-${pkg}-${env}"
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $JFROG_TOKEN" \
      "$JFROG_URL/artifactory/api/repositories/$REPO" 2>/dev/null || echo "000")
    if [[ "$STATUS" == "200" ]]; then
      green "Repo $REPO exists"
    else
      warn "Repo $REPO not found (HTTP $STATUS)"
      ((MISSING_REPOS++))
    fi
  done
done
if [[ $MISSING_REPOS -gt 0 ]]; then
  echo "  → Run: ./setup/bootstrap.sh to create missing repos"
fi

# ── IDE configs ──────────────────────────────────────────────────
section "IDE configuration"
SWIFTSHIP="$ROOT_DIR/e2e/swiftship"

if [[ -f "$SWIFTSHIP/.vscode/settings.json" ]]; then
  green ".vscode/settings.json exists"
else
  warn ".vscode/settings.json missing"
fi

if [[ -f "$SWIFTSHIP/.cursor/mcp.json" ]]; then
  green ".cursor/mcp.json exists"
  # Check MCP URL is set
  if [[ -n "${JFROG_MCP_URL:-}" ]]; then
    MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $JFROG_TOKEN" \
      "$JFROG_MCP_URL" 2>/dev/null || echo "000")
    if [[ "$MCP_STATUS" == "200" ]]; then
      green "JFrog MCP Server reachable at $JFROG_MCP_URL"
    else
      warn "JFrog MCP Server not responding (HTTP $MCP_STATUS) — enable at $JFROG_URL/ui/admin/integrations/mcp"
    fi
  else
    warn "JFROG_MCP_URL not set — MCP demo (Cursor/Claude Code) will not work"
  fi
else
  warn ".cursor/mcp.json missing"
fi

if [[ -f "$SWIFTSHIP/.claude/settings.json" ]]; then
  green ".claude/settings.json exists"
fi

# ── Vulnerable packages seeded ───────────────────────────────────
section "Demo data (vulnerable packages seeded)"
# Quick check: does the dev npm repo contain the seeded nx package?
NX_CHECK=$(curl -s \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  "$JFROG_URL/artifactory/api/search/artifact?name=nx&repos=${PREFIX}-npm-dev" 2>/dev/null || echo "{}")
if echo "$NX_CHECK" | grep -q '"uri"'; then
  green "Vulnerable npm packages found in ${PREFIX}-npm-dev"
else
  warn "Demo packages may not be seeded — run: ./setup/prep.sh"
fi

# ── Summary ──────────────────────────────────────────────────────
section "Summary"
echo "  Passed: $PASS  |  Warnings: $WARN  |  Failed: $FAIL"
echo
if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
  echo "  🎉  All checks passed — you're ready to demo!"
elif [[ $FAIL -eq 0 ]]; then
  echo "  ⚠️   Passed with warnings — review above before customer call"
else
  echo "  ❌  $FAIL check(s) failed — fix before demo"
  exit 1
fi
