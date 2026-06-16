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
skip()     { echo "  ⏭️   $1 (already exists)"; }
repo_put() {
  local LABEL=$1 KEY=$2 PAYLOAD=$3
  local TMPFILE STATUS
  TMPFILE=$(mktemp)
  STATUS=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -X PUT "$JFROG_URL/artifactory/api/repositories/$KEY" \
    -d "$PAYLOAD" 2>/dev/null)
  if [[ "$STATUS" == "200" || "$STATUS" == "201" ]]; then
    ok "$LABEL: $KEY"
  else
    echo "  ⚠️  $KEY returned HTTP $STATUS: $(cat "$TMPFILE")"
  fi
  rm -f "$TMPFILE"
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
jf config add "$JF_SERVER_ID" \
  --url="$JFROG_URL" \
  --access-token="$JFROG_TOKEN" \
  --interactive=false \
  --overwrite 2>/dev/null || true
ok "JFrog CLI server configured (id: $JF_SERVER_ID)"

# ── Create Artifactory repos ─────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--packages" ]]; then
  PREFIX="${JFROG_REPO_PREFIX:-swiftship}"
  step "Creating Artifactory repositories (${PREFIX}-{pkg}-{maturity}-{locator})"

  for PKG in maven gradle npm pypi docker go nuget helm; do
    case $PKG in
      maven|gradle) LAYOUT="maven-2-default" ; UPSTREAM="https://repo1.maven.org/maven2" ;;
      npm)          LAYOUT="npm-default"      ; UPSTREAM="https://registry.npmjs.org" ;;
      pypi)         LAYOUT="simple-default"   ; UPSTREAM="https://pypi.org" ;;
      docker)       LAYOUT="simple-default"   ; UPSTREAM="https://registry-1.docker.io" ;;
      go)           LAYOUT="go-default"       ; UPSTREAM="https://proxy.golang.org" ;;
      nuget)        LAYOUT="nuget-default"    ; UPSTREAM="https://api.nuget.org/v3/index.json" ;;
      helm)         LAYOUT="simple-default"   ; UPSTREAM="https://charts.helm.sh/stable" ;;
    esac

    for MATURITY in dev stage prod; do
      case $MATURITY in
        dev)   ENV_TAG="DEV"  ;;
        stage) ENV_TAG="TEST" ;;
        prod)  ENV_TAG="PROD" ;;
      esac

      LOCAL="${PREFIX}-${PKG}-${MATURITY}-local"
      REMOTE="${PREFIX}-${PKG}-${MATURITY}-remote"
      VIRTUAL="${PREFIX}-${PKG}-${MATURITY}-virtual"

      # projectKey and environments are omitted entirely when JFROG_PROJECT_KEY is unset
      if [[ -n "${JFROG_PROJECT_KEY:-}" ]]; then
        PROJ=", \"projectKey\": \"$JFROG_PROJECT_KEY\", \"environments\": [\"$ENV_TAG\"]"
      else
        PROJ=""
      fi

      repo_put "local" "$LOCAL" \
        "{\"key\":\"$LOCAL\",\"rclass\":\"local\",\"packageType\":\"$PKG\",\"repoLayoutRef\":\"$LAYOUT\",\"xrayIndex\":true,\"description\":\"SwiftShip $PKG $MATURITY local repository\"$PROJ}"

      repo_put "remote" "$REMOTE" \
        "{\"key\":\"$REMOTE\",\"rclass\":\"remote\",\"packageType\":\"$PKG\",\"repoLayoutRef\":\"$LAYOUT\",\"url\":\"$UPSTREAM\",\"xrayIndex\":true,\"description\":\"SwiftShip $PKG $MATURITY remote proxy\"$PROJ}"

      repo_put "virtual" "$VIRTUAL" \
        "{\"key\":\"$VIRTUAL\",\"rclass\":\"virtual\",\"packageType\":\"$PKG\",\"repoLayoutRef\":\"$LAYOUT\",\"repositories\":[\"$LOCAL\",\"$REMOTE\"],\"defaultDeploymentRepo\":\"$LOCAL\",\"description\":\"SwiftShip $PKG $MATURITY virtual repository\"$PROJ}"
    done
  done

  # AI/ML and Agentic repos — dev-only, no maturity split
  if [[ -n "${JFROG_PROJECT_KEY:-}" ]]; then
    AIML_PROJ=", \"projectKey\": \"$JFROG_PROJECT_KEY\", \"environments\": [\"DEV\"]"
  else
    AIML_PROJ=""
  fi

  for SPEC in \
    "huggingface:huggingfaceml" \
    "ml:ml" \
    "oci:oci" \
    "skills:skills" \
    "agent-plugins:agentplugins" \
    "ai-editor-ext:aieditorext"
  do
    PKG="${SPEC%%:*}"
    RTYPE="${SPEC##*:}"
    REPO="${PREFIX}-${PKG}-local"
    repo_put "local" "$REPO" \
      "{\"key\":\"$REPO\",\"rclass\":\"local\",\"packageType\":\"$RTYPE\",\"xrayIndex\":true,\"description\":\"SwiftShip $PKG repository\"$AIML_PROJ}"
  done
fi

# ── Xray watches + policies ──────────────────────────────────────
if [[ "$MODE" == "all" || "$MODE" == "--xray" ]]; then
  step "Creating Xray policies"

  # Delete existing policies and watch before recreating (ignore 404).
  for POLICY in security-policy license-policy operational-policy; do
    curl -s -o /dev/null \
      -H "Authorization: Bearer $JFROG_TOKEN" \
      -X DELETE "$JFROG_URL/xray/api/v2/policies/${TEAM}-${POLICY}?projectKey=$PROJECT_KEY" \
      2>/dev/null || true
  done
  curl -s -o /dev/null \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -X DELETE "$JFROG_URL/xray/api/v2/watches/${TEAM}-watch?projectKey=$PROJECT_KEY" \
    2>/dev/null || true

  # Security policy: CVSS 7.0–8.9 warn, CVSS 9.0–10.0 block
  xray_post "Security policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-security-policy\",
      \"type\": \"security\",
      \"rules\": [
        {
          \"name\": \"warn-high\",
          \"priority\": 1,
          \"criteria\": {\"cvss_range\": {\"from\": 7.0, \"to\": 8.9}},
          \"actions\": {\"fail_build\": false, \"notify_deployer\": true}
        },
        {
          \"name\": \"block-critical\",
          \"priority\": 2,
          \"criteria\": {\"cvss_range\": {\"from\": 9.0, \"to\": 10.0}},
          \"actions\": {
            \"fail_build\": true,
            \"block_release_bundle_promotion\": true,
            \"notify_watch_recipients\": true
          }
        }
      ]
    }"

  # License policy: block copyleft licenses
  xray_post "License policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-license-policy\",
      \"type\": \"license\",
      \"rules\": [{
        \"name\": \"block-copyleft\",
        \"priority\": 1,
        \"criteria\": {
          \"banned_licenses\": [\"AGPL-3.0\",\"GPL-2.0\",\"GPL-3.0\",\"GPL-2.0-only\",\"GPL-3.0-only\"],
          \"allow_unknown\": false
        },
        \"actions\": {
          \"fail_build\": true,
          \"block_release_bundle_promotion\": true,
          \"notify_watch_recipients\": true
        }
      }]
    }"

  # Operational risk policy: warn on high-risk components
  xray_post "Operational risk policy created" \
    "$JFROG_URL/xray/api/v2/policies?projectKey=$PROJECT_KEY" \
    "{
      \"name\": \"${TEAM}-operational-policy\",
      \"type\": \"operational_risk\",
      \"rules\": [{
        \"name\": \"warn-op-risk\",
        \"priority\": 1,
        \"criteria\": {\"op_risk_min_risk\": \"High\"},
        \"actions\": {
          \"fail_build\": false,
          \"notify_deployer\": true,
          \"notify_watch_recipients\": true
        }
      }]
    }"

  step "Creating Xray watch"
  # Watch all repos matching swiftship-.* via regex, assigned to all three policies.
  xray_post "Xray watch created" \
    "$JFROG_URL/xray/api/v2/watches?projectKey=$PROJECT_KEY" \
    "{
      \"general_data\": {\"name\": \"${TEAM}-watch\", \"active\": true},
      \"project_resources\": {
        \"resources\": [{
          \"type\": \"all-repos\",
          \"bin_mgr_id\": \"default\",
          \"filters\": [{\"type\": \"regex\", \"value\": \"${TEAM}-.*\"}]
        }]
      },
      \"assigned_policies\": [
        {\"name\": \"${TEAM}-security-policy\",    \"type\": \"security\"},
        {\"name\": \"${TEAM}-license-policy\",     \"type\": \"license\"},
        {\"name\": \"${TEAM}-operational-policy\", \"type\": \"operational_risk\"}
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
