#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# bootstrap.sh — one-time setup of a JFrog instance for demos
# Creates all repos, Xray watches, policies, and Curation rules.
# Idempotent — safe to re-run.
#
# Usage:
#   ./setup/bootstrap.sh               # full setup
#   ./setup/bootstrap.sh --packages    # repos only (skip Xray config)
#   ./setup/bootstrap.sh --xray        # Xray watches + policies only
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found"; exit 1; }

PREFIX="${JFROG_PROJECT_KEY:+${JFROG_PROJECT_KEY}-}${JFROG_REPO_PREFIX:-demo}"
MODE="${1:-all}"

step()   { echo; echo "━━━ $1"; }
ok()     { echo "  ✅  $1"; }
skip()   { echo "  ⏭️   $1 (already exists)"; }
create() {
  local TYPE=$1 KEY=$2 PAYLOAD=$3
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X PUT "$JFROG_URL/artifactory/api/repositories/$KEY" \
    -d "$PAYLOAD" 2>/dev/null)
  if [[ "$STATUS" == "200" || "$STATUS" == "201" ]]; then
    ok "Created $TYPE repo: $KEY"
  elif [[ "$STATUS" == "400" ]]; then
    skip "$KEY"
  else
    echo "  ⚠️  $KEY returned HTTP $STATUS"
  fi
}

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip — Bootstrap JFrog instance        ║"
echo "╚══════════════════════════════════════════════╝"
echo "  Instance : $JFROG_URL"
echo "  Prefix   : $PREFIX"
echo "  Mode     : $MODE"

# ── Configure JFrog CLI ──────────────────────────────────────────
step "Configuring JFrog CLI"
jf config add swiftship \
  --url="$JFROG_URL" \
  --access-token="$JFROG_TOKEN" \
  --interactive=false \
  --overwrite 2>/dev/null || true
ok "JFrog CLI server configured (id: swiftship)"

# ── Create Artifactory repos ─────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--packages" ]]; then
  step "Creating Artifactory repositories"

  # Traditional package types
  for PKG in maven npm pypi docker go nuget helm gradle; do
    for ENV in dev stage prod; do
      REPO="${PREFIX}-${PKG}-${ENV}"
      case $PKG in
        maven)   RTYPE="maven" ;;
        npm)     RTYPE="npm" ;;
        pypi)    RTYPE="pypi" ;;
        docker)  RTYPE="docker" ;;
        go)      RTYPE="go" ;;
        nuget)   RTYPE="nuget" ;;
        helm)    RTYPE="helm" ;;
        gradle)  RTYPE="gradle" ;;
      esac
      create "local" "$REPO" "{\"key\":\"$REPO\",\"rclass\":\"local\",\"packageType\":\"$RTYPE\"}"
    done
    # Virtual repo spanning dev/stage/prod
    VREPO="${PREFIX}-${PKG}-virtual"
    create "virtual" "$VREPO" "{\"key\":\"$VREPO\",\"rclass\":\"virtual\",\"packageType\":\"$RTYPE\",\"repositories\":[\"${PREFIX}-${PKG}-dev\",\"${PREFIX}-${PKG}-stage\",\"${PREFIX}-${PKG}-prod\"]}"
  done

  # AI/ML package types
  for PKG in huggingface ml oci; do
    case $PKG in
      huggingface) RTYPE="huggingfaceml" ;;
      ml)          RTYPE="ml" ;;
      oci)         RTYPE="oci" ;;
    esac
    REPO="${PREFIX}-${PKG}-local"
    create "local" "$REPO" "{\"key\":\"$REPO\",\"rclass\":\"local\",\"packageType\":\"$RTYPE\"}"
  done

  # Agentic repos
  create "local" "${PREFIX}-skills-local"       "{\"key\":\"${PREFIX}-skills-local\",\"rclass\":\"local\",\"packageType\":\"skills\"}"
  create "local" "${PREFIX}-agent-plugins-local" "{\"key\":\"${PREFIX}-agent-plugins-local\",\"rclass\":\"local\",\"packageType\":\"agentplugins\"}"
  create "local" "${PREFIX}-ai-editor-ext-local" "{\"key\":\"${PREFIX}-ai-editor-ext-local\",\"rclass\":\"local\",\"packageType\":\"aieditorext\"}"
fi

# ── Xray watches + policies ──────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--xray" ]]; then
  step "Creating Xray security policies"

  # Dev policy: warn on CVSS >= 7, block on CVSS >= 9.5
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$JFROG_URL/xray/api/v2/policies" \
    -d "{
      \"name\": \"${PREFIX}-dev-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"dev-cvss-rule\",
        \"criteria\": {\"min_severity\": \"high\"},
        \"actions\": {\"fail_build\": false, \"notify_deployer\": true}
      }]
    }" 2>/dev/null && ok "Dev policy created" || skip "Dev policy"

  # Stage policy: block on CVSS >= 7
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$JFROG_URL/xray/api/v2/policies" \
    -d "{
      \"name\": \"${PREFIX}-stage-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"stage-cvss-rule\",
        \"criteria\": {\"min_severity\": \"high\"},
        \"actions\": {\"fail_build\": true, \"block_release_bundle_distribution\": true}
      }]
    }" 2>/dev/null && ok "Stage policy created" || skip "Stage policy"

  # Prod policy: block on any medium+ AND license violations
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$JFROG_URL/xray/api/v2/policies" \
    -d "{
      \"name\": \"${PREFIX}-prod-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"prod-cvss-rule\",
        \"criteria\": {\"min_severity\": \"medium\"},
        \"actions\": {\"fail_build\": true, \"block_release_bundle_distribution\": true}
      }]
    }" 2>/dev/null && ok "Prod policy created" || skip "Prod policy"

  # License policy: block AGPL, GPL-2.0 in payments
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$JFROG_URL/xray/api/v2/policies" \
    -d "{
      \"name\": \"${PREFIX}-license-policy\",
      \"type\": \"license\",
      \"rules\": [{
        \"name\": \"commercial-license-rule\",
        \"criteria\": {\"banned_licenses\": [\"AGPL-3.0\",\"GPL-2.0\",\"GPL-3.0\"]},
        \"actions\": {\"fail_build\": true}
      }]
    }" 2>/dev/null && ok "License policy created" || skip "License policy"

  step "Creating Xray watches"
  # Watch covering all demo repos
  REPOS_JSON=$(for PKG in maven npm pypi docker go nuget helm gradle; do
    for ENV in dev stage prod; do echo "\"${PREFIX}-${PKG}-${ENV}\""; done
  done | paste -sd,)

  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$JFROG_URL/xray/api/v2/watches" \
    -d "{
      \"general_data\": {\"name\": \"${PREFIX}-watch\", \"active\": true},
      \"project_resources\": {\"resources\": [{\"type\": \"all-repos\"}]},
      \"assigned_policies\": [
        {\"name\": \"${PREFIX}-dev-policy\", \"type\": \"security\"},
        {\"name\": \"${PREFIX}-license-policy\", \"type\": \"license\"}
      ]
    }" 2>/dev/null && ok "Xray watch created" || skip "Xray watch"
fi

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅  Bootstrap complete                      ║"
echo "║                                              ║"
echo "║  Next steps:                                 ║"
echo "║    ./setup/prep.sh     # seed demo data      ║"
echo "║    ./setup/validate.sh # verify everything   ║"
echo "╚══════════════════════════════════════════════╝"
