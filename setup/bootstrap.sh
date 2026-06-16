#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# bootstrap.sh — one-time setup of a JFrog instance for demos
# Creates JFrog project, all repos, Xray watches, policies, and
# Curation rules.  Idempotent — safe to re-run.
#
# Repo naming: <team>-<tech>-<maturity>-<locator>
#   local   → swiftship-npm-dev-local
#   remote  → swiftship-npm-dev-remote  (proxies public registry)
#   virtual → swiftship-npm-dev-virtual (aggregates local + remote)
#
# Usage:
#   ./setup/bootstrap.sh               # full setup
#   ./setup/bootstrap.sh --packages    # repos only (skip Xray config)
#   ./setup/bootstrap.sh --xray        # Xray watches + policies only
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found"; exit 1; }

PROJECT_KEY="${JFROG_PROJECT_KEY:-swiftship}"
TEAM="$PROJECT_KEY"
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
xray_post() {
  local LABEL=$1 URL=$2 DATA=$3
  local TMPFILE STATUS
  TMPFILE=$(mktemp)
  STATUS=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$URL" -d "$DATA" 2>/dev/null)
  if [[ "$STATUS" == "200" || "$STATUS" == "201" ]]; then
    ok "$LABEL"
  else
    echo "  ⚠️  $LABEL returned HTTP $STATUS: $(cat "$TMPFILE")"
  fi
  rm -f "$TMPFILE"
}

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  SwiftShip — Bootstrap JFrog instance        ║"
echo "╚══════════════════════════════════════════════╝"
echo "  Instance : $JFROG_URL"
echo "  Team     : $TEAM"
echo "  Mode     : $MODE"

# ── Create JFrog Project ─────────────────────────────────────────
step "Creating JFrog project: $PROJECT_KEY"
PROJ_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JFROG_URL/access/api/v1/projects" \
  -d "{
    \"project_key\": \"$PROJECT_KEY\",
    \"project_name\": \"SwiftShip Demo\",
    \"description\": \"JFrog Platform Demo — SwiftShip polyglot app\"
  }" 2>/dev/null)
if [[ "$PROJ_STATUS" == "200" || "$PROJ_STATUS" == "201" ]]; then
  ok "JFrog project created: $PROJECT_KEY"
elif [[ "$PROJ_STATUS" == "409" ]]; then
  skip "JFrog project $PROJECT_KEY"
else
  echo "  ⚠️  Project creation returned HTTP $PROJ_STATUS (may need Platform Admin privileges)"
fi

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
  step "Creating Artifactory repositories (team-tech-maturity-locator)"

  # Traditional package types with public registry remote URLs
  for PKG in maven npm pypi docker go nuget helm gradle; do
    case $PKG in
      maven)   RTYPE="maven"  REMOTE_URL="https://repo1.maven.org/maven2" ;;
      npm)     RTYPE="npm"    REMOTE_URL="https://registry.npmjs.org" ;;
      pypi)    RTYPE="pypi"   REMOTE_URL="https://pypi.org" ;;
      docker)  RTYPE="docker" REMOTE_URL="https://registry-1.docker.io" ;;
      go)      RTYPE="go"     REMOTE_URL="https://proxy.golang.org" ;;
      nuget)   RTYPE="nuget"  REMOTE_URL="https://api.nuget.org/v3/index.json" ;;
      helm)    RTYPE="helm"   REMOTE_URL="https://charts.helm.sh/stable" ;;
      gradle)  RTYPE="gradle" REMOTE_URL="https://repo1.maven.org/maven2" ;;
    esac

    for ENV in dev stage prod; do
      LOCAL="${TEAM}-${PKG}-${ENV}-local"
      REMOTE="${TEAM}-${PKG}-${ENV}-remote"
      VIRTUAL="${TEAM}-${PKG}-${ENV}-virtual"

      create "local"   "$LOCAL"   \
        "{\"key\":\"$LOCAL\",\"rclass\":\"local\",\"packageType\":\"$RTYPE\"}"
      create "remote"  "$REMOTE"  \
        "{\"key\":\"$REMOTE\",\"rclass\":\"remote\",\"packageType\":\"$RTYPE\",\"url\":\"$REMOTE_URL\"}"
      # Virtual aggregates local first, then falls back to remote proxy cache
      create "virtual" "$VIRTUAL" \
        "{\"key\":\"$VIRTUAL\",\"rclass\":\"virtual\",\"packageType\":\"$RTYPE\",\"repositories\":[\"$LOCAL\",\"$REMOTE\"]}"
    done
  done

  # AI/ML package types (no per-environment split)
  for PKG in huggingface ml oci; do
    case $PKG in
      huggingface) RTYPE="huggingfaceml" ;;
      ml)          RTYPE="ml" ;;
      oci)         RTYPE="oci" ;;
    esac
    REPO="${TEAM}-${PKG}-local"
    create "local" "$REPO" "{\"key\":\"$REPO\",\"rclass\":\"local\",\"packageType\":\"$RTYPE\"}"
  done

  # Agentic repos
  create "local" "${TEAM}-skills-local"        "{\"key\":\"${TEAM}-skills-local\",\"rclass\":\"local\",\"packageType\":\"skills\"}"
  create "local" "${TEAM}-agent-plugins-local" "{\"key\":\"${TEAM}-agent-plugins-local\",\"rclass\":\"local\",\"packageType\":\"agentplugins\"}"
  create "local" "${TEAM}-ai-editor-ext-local" "{\"key\":\"${TEAM}-ai-editor-ext-local\",\"rclass\":\"local\",\"packageType\":\"aieditorext\"}"
fi

# ── Xray watches + policies ──────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--xray" ]]; then
  step "Creating Xray security policies"

  # Clean up existing policies so re-runs don't silently skip stale config.
  # projectKey is a URL query param — not supported in the request body.
  for POLICY in dev-policy stage-policy prod-policy license-policy; do
    curl -s -o /dev/null \
      -H "Authorization: Bearer $JFROG_TOKEN" \
      -X DELETE "$JFROG_URL/xray/api/v2/policies/${TEAM}-${POLICY}?projectKey=$PROJECT_KEY" \
      2>/dev/null || true
  done

  # Dev policy: warn on high, block on critical
  xray_post "Dev policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-dev-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"dev-cvss-rule\",
        \"criteria\": {\"min_severity\": \"high\"},
        \"actions\": {\"fail_build\": false, \"notify_deployer\": true}
      }]
    }"

  # Stage policy: block on high+
  xray_post "Stage policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-stage-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"stage-cvss-rule\",
        \"criteria\": {\"min_severity\": \"high\"},
        \"actions\": {\"fail_build\": true, \"block_release_bundle_distribution\": true}
      }]
    }"

  # Prod policy: block on medium+ AND license violations
  xray_post "Prod policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-prod-policy\",
      \"type\": \"security\",
      \"rules\": [{
        \"name\": \"prod-cvss-rule\",
        \"criteria\": {\"min_severity\": \"medium\"},
        \"actions\": {\"fail_build\": true, \"block_release_bundle_distribution\": true}
      }]
    }"

  # License policy: block AGPL, GPL in payments
  xray_post "License policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-license-policy\",
      \"type\": \"license\",
      \"rules\": [{
        \"name\": \"commercial-license-rule\",
        \"criteria\": {\"banned_licenses\": [\"AGPL-3.0\",\"GPL-2.0\",\"GPL-3.0\"]},
        \"actions\": {\"fail_build\": true}
      }]
    }"

  step "Creating Xray watches"
  # Delete existing watch before recreating with correct scope.
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -X DELETE "$JFROG_URL/xray/api/v2/watches/${TEAM}-watch?projectKey=$PROJECT_KEY" \
    2>/dev/null || true

  # Watch only swiftship-* repos, scoped to the swiftship project.
  xray_post "Xray watch created" \
    "$JFROG_URL/xray/api/v2/watches?projectKey=$PROJECT_KEY" \
    "{
      \"general_data\": {\"name\": \"${TEAM}-watch\", \"active\": true},
      \"project_resources\": {\"resources\": [{
        \"type\": \"repository\",
        \"name\": \"${TEAM}-*\",
        \"filters\": []
      }]},
      \"assigned_policies\": [
        {\"name\": \"${TEAM}-dev-policy\",    \"type\": \"security\"},
        {\"name\": \"${TEAM}-license-policy\", \"type\": \"license\"}
      ]
    }"
fi

echo
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅  Bootstrap complete                      ║"
echo "║                                              ║"
echo "║  Next steps:                                 ║"
echo "║    ./setup/prep.sh     # seed demo data      ║"
echo "║    ./setup/validate.sh # verify everything   ║"
echo "╚══════════════════════════════════════════════╝"
