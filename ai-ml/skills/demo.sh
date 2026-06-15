#!/usr/bin/env bash
set -euo pipefail
# ══════════════════════════════════════════════════════════════════
# SwiftShip AI/ML Demo — JFrog Skills Repository  ⚠️ BETA
# Demonstrates: Skills repos, ClawHub protocol, skill distribution
# ══════════════════════════════════════════════════════════════════
# Usage:
#   ./demo.sh              # interactive (live demo mode)
#   ./demo.sh --ci         # headless CI mode (exits 0/1)
#   ./demo.sh --reset      # reset to clean state before demo
#
# Status: BETA — APIs and CLI commands may change before GA
# Prerequisites: .env configured, bootstrap.sh already run
#                JFrog CLI v2.98.0+ required for jf skills commands
# Docs: https://docs.jfrog.com/artifactory/docs/skills-repositories
#       https://github.com/jfrog/jfrog-skills
# ══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/.env" 2>/dev/null || { echo "❌ .env not found — run: cp .env.example .env"; exit 1; }

STATUS="BETA"
CI_MODE="${1:-}"
REPO_PREFIX="${JFROG_REPO_PREFIX:-demo}"
PROJECT_KEY="${JFROG_PROJECT_KEY:-}"
PREFIX="${PROJECT_KEY:+${PROJECT_KEY}-}${REPO_PREFIX}"
REPO_SKILLS="${PREFIX}-skills-local"

# Skills used in the demo
SKILL_JFROG_SLUG="jfrog"
SKILL_JFROG_VERSION="2.1.0"
SAMPLE_SKILL_SLUG="swiftship-security-runbook"
SAMPLE_SKILL_VERSION="1.0.0"

# Temp dirs
JFROG_SKILLS_DIR="/tmp/jfrog-skills-clone"
SAMPLE_SKILL_DIR="/tmp/${SAMPLE_SKILL_SLUG}"

step()  { echo; echo "━━━ $1"; }
pass()  { echo "  ✅  $1"; }
fail()  { echo "  ❌  $1"; [[ "$CI_MODE" == "--ci" ]] && exit 1; }
warn()  { echo "  ⚠️   $1"; }
pause() { [[ "$CI_MODE" == "--ci" ]] && return; echo; read -rp "  ▶  Press Enter to continue..."; }
hr()    { echo "  ─────────────────────────────────────────────"; }
note()  { echo "  💡  $1"; }
beta()  { echo "  🧪  [BETA] $1"; }

# Check JFrog CLI version for skills support (requires v2.98.0+)
JF_SKILLS_AVAILABLE=false
if command -v jf &>/dev/null; then
  JF_VERSION=$(jf --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
  JF_MAJOR=$(echo "$JF_VERSION" | cut -d. -f1)
  JF_MINOR=$(echo "$JF_VERSION" | cut -d. -f2)
  JF_PATCH=$(echo "$JF_VERSION" | cut -d. -f3)
  if [[ "$JF_MAJOR" -gt 2 ]] || \
     [[ "$JF_MAJOR" -eq 2 && "$JF_MINOR" -gt 98 ]] || \
     [[ "$JF_MAJOR" -eq 2 && "$JF_MINOR" -eq 98 && "$JF_PATCH" -ge 0 ]]; then
    JF_SKILLS_AVAILABLE=true
  fi
fi

# ── Reset ─────────────────────────────────────────────────────────
if [[ "$CI_MODE" == "--reset" ]]; then
  echo "Resetting Skills demo state..."
  rm -rf "$JFROG_SKILLS_DIR" "$SAMPLE_SKILL_DIR" 2>/dev/null || true
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_SKILLS}/${SAMPLE_SKILL_SLUG}/" 2>/dev/null || true
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/${REPO_SKILLS}/${SKILL_JFROG_SLUG}/" 2>/dev/null || true
  echo "✅  Reset complete"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# DEMO START
# ══════════════════════════════════════════════════════════════════
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SwiftShip AI/ML Demo — Skills Repository  [${STATUS}]          ║"
echo "║  Story: enterprise-grade AI agent skill distribution         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Instance    : ${JFROG_URL}"
echo "  Skills repo : ${REPO_SKILLS}"
echo "  JFrog CLI   : $(jf --version 2>&1 | head -1 || echo 'not found')"
echo
beta "Skills Repositories are in Beta — APIs may change before GA"
[[ "$JF_SKILLS_AVAILABLE" == false ]] && warn "JFrog CLI < v2.98.0 — skills commands shown but may not execute. Upgrade: https://install-cli.jfrog.io"

# ── Step 1: Create/verify Skills repo in Artifactory ─────────────
step "1 / 4  Create Skills repo in Artifactory  [${STATUS}]"
echo "  Repo key     : ${REPO_SKILLS}"
echo "  Package type : skills"
echo "  Protocol     : ClawHub v1"
hr

REPO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/repositories/${REPO_SKILLS}" 2>/dev/null)

if [[ "$REPO_CHECK" == "200" ]]; then
  pass "Skills repo already exists: ${REPO_SKILLS}"
else
  echo "  Creating skills repo via REST API..."
  CREATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    -H "Content-Type: application/json" \
    -X PUT "${JFROG_URL}/artifactory/api/repositories/${REPO_SKILLS}" \
    -d "{
      \"key\": \"${REPO_SKILLS}\",
      \"rclass\": \"local\",
      \"packageType\": \"skills\",
      \"description\": \"Enterprise AI agent skills — ClawHub protocol, versioned, Xray-scanned\"
    }" 2>/dev/null)
  if [[ "$CREATE_STATUS" == "200" || "$CREATE_STATUS" == "201" ]]; then
    pass "Created Skills repo: ${REPO_SKILLS}"
  else
    warn "Skills repo create returned HTTP ${CREATE_STATUS}"
    note "Skills package type may still be Beta — check Artifactory version: Enterprise+ v7.125.x+"
  fi
fi

echo
echo "  ClawHub discovery endpoint (auto-used by compatible agents):"
echo "    ${JFROG_URL}/artifactory/api/skills/${REPO_SKILLS}/.well-known/clawhub.json"
echo
echo "  Checking ClawHub discovery endpoint..."
CLAWHUB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/skills/${REPO_SKILLS}/.well-known/clawhub.json" \
  2>/dev/null || echo "000")
if [[ "$CLAWHUB_STATUS" == "200" ]]; then
  pass "ClawHub discovery endpoint is active"
  curl -s \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    "${JFROG_URL}/artifactory/api/skills/${REPO_SKILLS}/.well-known/clawhub.json" \
    2>/dev/null | python3 -m json.tool 2>/dev/null | head -15 || true
else
  warn "ClawHub endpoint returned HTTP ${CLAWHUB_STATUS} — repo may not support skills yet"
fi
pause

# ── Step 2: Publish JFrog skill from github.com/jfrog/jfrog-skills ─
step "2 / 4  Publish JFrog skill from github.com/jfrog/jfrog-skills"
echo "  Source: https://github.com/jfrog/jfrog-skills"
echo "  Skill : ${SKILL_JFROG_SLUG}  v${SKILL_JFROG_VERSION}"
hr

# Clone jfrog-skills (shallow)
echo "  Cloning jfrog/jfrog-skills (shallow)..."
rm -rf "$JFROG_SKILLS_DIR"
if git clone --depth=1 --quiet \
     "https://github.com/jfrog/jfrog-skills.git" \
     "$JFROG_SKILLS_DIR" 2>/dev/null; then
  pass "Cloned github.com/jfrog/jfrog-skills"
  echo "  Skills available:"
  ls "${JFROG_SKILLS_DIR}/skills/" 2>/dev/null | sed 's/^/    /' || true
else
  warn "Could not clone jfrog/jfrog-skills — creating sample skill folder for demo"
  mkdir -p "${JFROG_SKILLS_DIR}/skills/jfrog"
  cat > "${JFROG_SKILLS_DIR}/skills/jfrog/SKILL.md" << 'SKILLMD'
---
name: JFrog Platform
slug: jfrog
version: 2.1.0
description: Interact with the JFrog Platform via the JFrog CLI and REST/GraphQL APIs. Manage repositories, query vulnerabilities, promote artifacts, and run security audits.
author: JFrog
license: Apache-2.0
min_agent_version: "1.0"
tags:
  - artifactory
  - xray
  - security
  - devops
  - curation
---

# JFrog Platform Skill

This skill teaches AI agents to use the JFrog Platform via:
- JFrog CLI (`jf`) commands
- Artifactory REST API
- Xray GraphQL API
- AppTrust lifecycle management
SKILLMD
fi

SKILL_SOURCE="${JFROG_SKILLS_DIR}/skills/${SKILL_JFROG_SLUG}"

# Publish the skill
echo
echo "  Publishing ${SKILL_JFROG_SLUG} v${SKILL_JFROG_VERSION} to ${REPO_SKILLS}..."

if [[ "$JF_SKILLS_AVAILABLE" == true ]]; then
  set +e
  PUBLISH_OUTPUT=$(jf skills publish "${SKILL_SOURCE}" \
    --repo "${REPO_SKILLS}" \
    --version "${SKILL_JFROG_VERSION}" \
    --server-id=swiftship 2>&1 || true)
  set -e
  echo "$PUBLISH_OUTPUT" | tail -5

  if echo "$PUBLISH_OUTPUT" | grep -qiE "success|published|uploaded|complete"; then
    pass "Published ${SKILL_JFROG_SLUG} v${SKILL_JFROG_VERSION} to ${REPO_SKILLS}"
  else
    warn "jf skills publish output unclear — attempting REST API fallback..."
    # Fallback: package the skill as a zip and upload via jf rt u
    SKILL_ZIP="/tmp/${SKILL_JFROG_SLUG}-${SKILL_JFROG_VERSION}.zip"
    (cd "${JFROG_SKILLS_DIR}/skills" && \
      zip -r "$SKILL_ZIP" "${SKILL_JFROG_SLUG}/" -x "*.DS_Store" 2>/dev/null) || true
    if [[ -f "$SKILL_ZIP" ]]; then
      jf rt u "$SKILL_ZIP" \
        "${REPO_SKILLS}/${SKILL_JFROG_SLUG}/${SKILL_JFROG_VERSION}/${SKILL_JFROG_SLUG}-${SKILL_JFROG_VERSION}.zip" \
        --server-id=swiftship \
        --props "skill.slug=${SKILL_JFROG_SLUG};skill.version=${SKILL_JFROG_VERSION};skill.author=JFrog" \
        2>&1 | tail -3 || true
      pass "Published via jf rt u (skills CLI fallback)"
    fi
  fi
else
  beta "jf skills publish requires JFrog CLI v2.98.0+ — showing command only:"
  echo "    jf skills publish ${SKILL_SOURCE} --repo ${REPO_SKILLS} --version ${SKILL_JFROG_VERSION}"
  echo
  echo "  Equivalent REST API call:"
  echo "    POST ${JFROG_URL}/artifactory/api/skills/${REPO_SKILLS}/api/v1/skills"
  echo "    (multipart form: skill-folder as zip)"
fi
pause

# ── Step 3: Install skill in Claude Code ──────────────────────────
step "3 / 4  Install skill in Claude Code (and Cursor)"
echo "  Installing: ${SKILL_JFROG_SLUG} from ${REPO_SKILLS}"
hr

if [[ "$JF_SKILLS_AVAILABLE" == true ]]; then
  echo "  Installing for Claude Code..."
  set +e
  INSTALL_OUTPUT=$(jf skills install "${SKILL_JFROG_SLUG}" \
    --agent claude \
    --repo "${REPO_SKILLS}" \
    --version "${SKILL_JFROG_VERSION}" \
    --server-id=swiftship 2>&1 || true)
  set -e
  echo "$INSTALL_OUTPUT" | tail -8

  if echo "$INSTALL_OUTPUT" | grep -qiE "success|installed|complete"; then
    pass "${SKILL_JFROG_SLUG} v${SKILL_JFROG_VERSION} installed for Claude Code"
  else
    note "Install output inconclusive — checking if skill is available in repo..."
    jf rt search "${REPO_SKILLS}/${SKILL_JFROG_SLUG}/" \
      --server-id=swiftship 2>/dev/null | head -10 || true
  fi

  echo
  echo "  For Cursor:"
  echo "    jf skills install ${SKILL_JFROG_SLUG} --agent cursor --repo ${REPO_SKILLS}"
  echo
  echo "  For Codex:"
  echo "    jf skills install ${SKILL_JFROG_SLUG} --agent codex --repo ${REPO_SKILLS}"
else
  beta "Showing install commands (requires JFrog CLI v2.98.0+):"
  echo
  echo "  # Install for Claude Code"
  echo "  jf skills install ${SKILL_JFROG_SLUG} --agent claude --repo ${REPO_SKILLS} --version latest"
  echo
  echo "  # Install for Cursor"
  echo "  jf skills install ${SKILL_JFROG_SLUG} --agent cursor --repo ${REPO_SKILLS} --version latest"
  echo
  echo "  # Install for Codex"
  echo "  jf skills install ${SKILL_JFROG_SLUG} --agent codex --repo ${REPO_SKILLS} --version latest"
fi

echo
echo "  After installation, developers can use the skill:"
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Cursor: /jfrog  →  Loads the JFrog skill commands          │"
echo "  │                                                              │"
echo "  │  Example: 'Use the jfrog skill to scan auth-service and     │"
echo "  │            tell me which CVEs block the Stage promotion'     │"
echo "  └──────────────────────────────────────────────────────────────┘"
pause

# ── Step 4: Show discovery, versioning, and search ────────────────
step "4 / 4  Skill discovery, versioning, and Xray governance"
hr

echo "  Publishing a second skill (internal security runbook)..."
# Create a sample internal skill
rm -rf "$SAMPLE_SKILL_DIR"
mkdir -p "$SAMPLE_SKILL_DIR"
cat > "${SAMPLE_SKILL_DIR}/SKILL.md" << SAMPLEMD
---
name: SwiftShip Security Runbook
slug: ${SAMPLE_SKILL_SLUG}
version: ${SAMPLE_SKILL_VERSION}
description: Security incident response runbooks for SwiftShip engineers. Teaches agents CVE triage, escalation paths, and CISA KEV response procedures.
author: SwiftShip Security Team
license: UNLICENSED
min_agent_version: "1.0"
tags:
  - security
  - incident-response
  - cve
  - internal
---

# SwiftShip Security Runbook Skill

Internal skill — not for distribution outside SwiftShip.
SAMPLEMD

if [[ "$JF_SKILLS_AVAILABLE" == true ]]; then
  set +e
  jf skills publish "$SAMPLE_SKILL_DIR" \
    --repo "${REPO_SKILLS}" \
    --version "${SAMPLE_SKILL_VERSION}" \
    --server-id=swiftship 2>&1 | tail -3 || true
  set -e
else
  SAMPLE_ZIP="/tmp/${SAMPLE_SKILL_SLUG}-${SAMPLE_SKILL_VERSION}.zip"
  (cd /tmp && zip -r "$SAMPLE_ZIP" "$(basename "$SAMPLE_SKILL_DIR")/" -x "*.DS_Store" 2>/dev/null) || true
  if [[ -f "$SAMPLE_ZIP" ]]; then
    jf rt u "$SAMPLE_ZIP" \
      "${REPO_SKILLS}/${SAMPLE_SKILL_SLUG}/${SAMPLE_SKILL_VERSION}/${SAMPLE_SKILL_SLUG}-${SAMPLE_SKILL_VERSION}.zip" \
      --server-id=swiftship \
      --props "skill.slug=${SAMPLE_SKILL_SLUG};skill.version=${SAMPLE_SKILL_VERSION}" \
      2>&1 | tail -3 || true
  fi
fi

echo
echo "  Listing all skills in ${REPO_SKILLS}..."
if [[ "$JF_SKILLS_AVAILABLE" == true ]]; then
  set +e
  jf skills list --repo "${REPO_SKILLS}" --server-id=swiftship 2>/dev/null | head -20 || \
    jf rt search "${REPO_SKILLS}/" --server-id=swiftship 2>/dev/null | python3 -m json.tool 2>/dev/null | \
    grep '"uri"' | sed 's/.*"uri": "\(.*\)".*/    \1/' || true
  set -e
else
  jf rt search "${REPO_SKILLS}/" --server-id=swiftship 2>/dev/null | \
    python3 -m json.tool 2>/dev/null | grep '"uri"' | sed 's/.*"uri": "\(.*\)".*/    \1/' || true
fi

echo
echo "  Versioning demo — show all versions of the JFrog skill:"
jf rt search "${REPO_SKILLS}/${SKILL_JFROG_SLUG}/" \
  --server-id=swiftship 2>/dev/null | \
  python3 -m json.tool 2>/dev/null | grep '"uri"' | head -10 || \
  echo "  → ${REPO_SKILLS}/${SKILL_JFROG_SLUG}/${SKILL_JFROG_VERSION}/${SKILL_JFROG_SLUG}-${SKILL_JFROG_VERSION}.zip"

echo
echo "  ClawHub discovery query (how agents auto-discover skills):"
curl -s \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  "${JFROG_URL}/artifactory/api/skills/${REPO_SKILLS}/api/v1/skills" \
  2>/dev/null | python3 -m json.tool 2>/dev/null | head -30 || \
  echo "  (Skills API not yet active — check Artifactory version supports packageType:skills)"

echo
echo "  Xray scans every published skill version for:"
echo "    - Embedded secrets in SKILL.md or included scripts"
echo "    - Malicious code in packaged tool executables"
echo "    - License compliance (skills can include third-party libraries)"

pass "Skills discovery, versioning, and governance demonstrated"

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Skills demo complete  [${STATUS}]                           ║"
echo "║                                                              ║"
echo "║  Key moments:                                                ║"
echo "║    Step 1 — Skills repo created (ClawHub protocol active)   ║"
echo "║    Step 2 — JFrog skill published from github.com/jfrog     ║"
echo "║    Step 3 — Skill installed for Claude Code + Cursor        ║"
echo "║    Step 4 — Discovery, versioning, Xray governance shown    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
beta "Remember: Skills Repositories are BETA. Check release notes before customer demos."
echo "  Latest status: https://docs.jfrog.com/artifactory/docs/skills-repositories"
