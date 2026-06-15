# SwiftShip E2E Demo — Night-Before Prep Checklist

Run through this list the evening before your customer call.
Each item has the exact command to verify it. Check off everything before you sleep.

---

## Environment

- [ ] **`.env` file is populated**
  Copy `e2e/swiftship/booking-service/.env.example` to `e2e/swiftship/.env` and confirm
  every variable is set (no empty values):
  ```bash
  grep -E "^[A-Z_]+=\s*$" e2e/swiftship/.env && echo "EMPTY VARS — FIX BEFORE DEMO" || echo "OK"
  ```
  Required vars: `JFROG_URL`, `JFROG_USER`, `JFROG_TOKEN`, `JFROG_PROJECT_KEY`,
  `JFROG_REPO_PREFIX`, `JFROG_MCP_URL`, `SLACK_WEBHOOK_URL`.

- [ ] **JFrog CLI is authenticated and talking to the right instance**
  ```bash
  jf config show          # confirm server ID and URL match your demo instance
  jf rt ping              # should print "OK"
  ```
  If `jf config show` is empty: `jf config add demo-server --url $JFROG_URL --user $JFROG_USER --password $JFROG_TOKEN`

- [ ] **Connectivity to Artifactory repos is working**
  ```bash
  # npm virtual repo (used by Stage B — Curation)
  curl -s -u "$JFROG_USER:$JFROG_TOKEN" \
    "$JFROG_URL/artifactory/api/storage/${JFROG_REPO_PREFIX}-npm-dev/" | jq '.repo'

  # Maven virtual repo (used by Stage A — auth-service)
  curl -s -u "$JFROG_USER:$JFROG_TOKEN" \
    "$JFROG_URL/artifactory/api/storage/${JFROG_REPO_PREFIX}-maven-dev/" | jq '.repo'
  ```
  Both should return the repo name without a 404 or 401.

- [ ] **AppTrust API is reachable and all 8 applications exist**
  ```bash
  jf apptrust app-list --project $JFROG_PROJECT_KEY --format json | \
    jq '[.[] | .app_key]'
  ```
  Expected output (order may vary):
  ```json
  [
    "swiftship-auth-service",
    "swiftship-storefront-ui",
    "swiftship-booking-service",
    "swiftship-payments-service",
    "swiftship-logistics-service",
    "swiftship-recommendation-engine",
    "swiftship-ai-assistant",
    "swiftship-infra"
  ]
  ```
  If any are missing: `bash setup/bootstrap.sh --apptrust`

- [ ] **JFrog MCP Server is reachable from Claude Code / Cursor**
  ```bash
  curl -s -H "Authorization: Bearer $JFROG_TOKEN" \
    "$JFROG_MCP_URL/health" | jq '.status'
  ```
  Should return `"ok"`. If it returns 401, regenerate your token in the JFrog UI
  (Platform → Administration → Access Tokens) and update `JFROG_TOKEN` in `.env`.

---

## IDE Setup

### VS Code

- [ ] **JFrog VS Code extension is installed and connected**
  Open `e2e/swiftship/auth-service/pom.xml` in VS Code.
  Bottom status bar should show a JFrog icon. Click it — "Connected" badge should appear.
  If not connected: open VS Code Settings → search "jfrog" → verify
  `jfrog.url`, `jfrog.xray.username`, `jfrog.xray.password` match your `.env`.
  (Settings are pre-wired in `e2e/swiftship/.vscode/settings.json`.)

- [ ] **Xray inline scan triggers on save**
  Open `e2e/swiftship/auth-service/pom.xml`, add a trailing space, save.
  Within ~10 seconds a wavy red underline should appear under `spring-core 6.1.6`.
  Hover → tooltip must show **CVE-2025-41234 (CVSS 9.8)**.
  If no underline: check `"jfrog.xray.scanOnSave": true` in `.vscode/settings.json`.

- [ ] **The three demo CVEs are all inline-highlighted in `pom.xml`**
  Open the file and confirm squiggles on all three VULN-SEED deps:
  - `spring-core 6.1.6` → CVE-2025-41234 (RCE, 9.8)
  - `spring-security-core 6.2.3` → CVE-2025-41248 (auth bypass, 9.1)
  - `spring-boot-starter-parent 2.7.18` → CVE-2024-38816 (path traversal, 7.5)

### Cursor / Claude Code

- [ ] **JFrog MCP server is loaded in Cursor**
  Open Cursor in `e2e/swiftship/`. Click the MCP icon (puzzle piece) in the sidebar.
  "jfrog" should appear in the server list with a green connected indicator.
  Config lives at `e2e/swiftship/.cursor/mcp.json` — verify `JFROG_MCP_URL` and
  `JFROG_TOKEN` are being interpolated (no literal `${}` in the rendered URL).

- [ ] **MCP query returns live Xray data**
  In Cursor Chat, type:
  ```
  @jfrog what critical CVEs are in the SwiftShip auth-service?
  ```
  Should return CVE-2025-41234 and CVE-2025-41248 with CVSS scores.
  If it returns "no results" or an error, the MCP server cannot reach Xray —
  re-check `JFROG_MCP_URL` (it must include `/mcp/v1` or equivalent path).

- [ ] **Claude Code MCP connection works in the terminal**
  Open `e2e/swiftship/` in a Claude Code session. Run:
  ```
  /mcp
  ```
  "jfrog" should appear as a connected server. Then ask:
  ```
  What are the CISA KEV findings across the SwiftShip platform?
  ```
  Expected: mention of CVE-2025-3248 (Langflow, booking-service) and CVE-2025-41234
  (Spring RCE, auth-service).

---

## Demo Data

- [ ] **Vulnerable packages are seeded in Artifactory**
  Each service's VULN-SEED deps must have been uploaded by `setup/bootstrap.sh --seed`.
  Spot-check three representative packages:
  ```bash
  # Spring Core 6.1.6 (auth-service)
  jf rt s "${JFROG_REPO_PREFIX}-maven-dev/org/springframework/spring-core/6.1.6/*.jar" \
    --count | grep -v "^0$" || echo "MISSING — run bootstrap.sh --seed"

  # Langflow 1.1.4 (booking-service + recommendation-engine)
  jf rt s "${JFROG_REPO_PREFIX}-pypi-dev/langflow/langflow-1.1.4*.whl" \
    --count | grep -v "^0$" || echo "MISSING — run bootstrap.sh --seed"

  # @nx/devkit 19.5.0 (storefront-ui, Curation target)
  jf rt s "${JFROG_REPO_PREFIX}-npm-dev/@nx/devkit/-/devkit-19.5.0.tgz" \
    --count | grep -v "^0$" || echo "MISSING — run bootstrap.sh --seed"
  ```

- [ ] **Xray findings are visible in the Violations view**
  In the JFrog UI: **Xray → Violations**. Filter by Watch `${JFROG_REPO_PREFIX}-watch`.
  Confirm you can see at minimum:
  - CVE-2025-41234 (Critical, auth-service) — CISA KEV
  - CVE-2025-3248 (Critical, booking-service) — CISA KEV
  - CVE-2024-21907 (High, payments-service)
  - AGPL-3.0 iTextSharp (License violation, payments-service)

  If violations are empty: **Xray → Watches → `${JFROG_REPO_PREFIX}-watch` → Recalculate**

- [ ] **Curation policies are active and blocking `@nx/devkit@19.5.0`**
  ```bash
  # Attempt the install through the Curation-enforced npm virtual repo.
  # This SHOULD be blocked — verify you see a 403 / "blocked by Curation" error.
  cd /tmp && mkdir curation-test && cd curation-test && \
    NPM_CONFIG_REGISTRY="$JFROG_URL/artifactory/api/npm/${JFROG_REPO_PREFIX}-npm-dev/" \
    npm install @nx/devkit@19.5.0 2>&1 | grep -i "block\|curat\|403" || \
    echo "NOT BLOCKED — check Curation policy in JFrog UI"
  rm -rf /tmp/curation-test
  ```
  In the JFrog UI: **Curation → Audit** should show the blocked attempt.

- [ ] **AppTrust Applications exist with the correct stages**
  ```bash
  # Check that DEV, STAGE, and PROD stages are created
  jf apptrust stage-list --project $JFROG_PROJECT_KEY --format json | \
    jq '[.[] | .stage_key]'
  ```
  Expected: `["DEV", "STAGE", "PROD"]`
  Then verify payments-service has a version at DEV with violations:
  ```bash
  jf apptrust version-list swiftship-payments-service \
    --project $JFROG_PROJECT_KEY --format json | jq '.[0]'
  ```

---

## Dry Run

- [ ] **`jf audit` in auth-service returns the expected CVEs**
  ```bash
  cd e2e/swiftship/auth-service
  jf audit --mvn --extended-table
  ```
  Table must show CVE-2025-41234 (CVSS 9.8) and CVE-2025-41248 (CVSS 9.1) in red.
  Runtime: ~30 seconds. If it hangs >2 min, kill it — the Maven repo may be unreachable.
  Fallback: `jf audit --mvn --format json | jq '.vulnerabilities[] | {cve: .cves[].id, cvss: .cvss3_score}'`

- [ ] **Frogbot is active on the `demo/booking-service-vuln` branch**
  ```bash
  # Check the branch exists and has a Frogbot PR comment
  gh pr list --repo <YOUR_DEMO_REPO> --head demo/booking-service-vuln --json number,title,body
  ```
  The PR body should contain a Frogbot security scan table.
  If missing: trigger Frogbot manually by pushing a commit to the branch, or run
  `gh workflow run frogbot.yml` from the demo repo.

- [ ] **AppTrust Stages Board shows all 8 services**
  Open the JFrog UI: **AppTrust → Stages Board**.
  All 8 SwiftShip applications should appear as rows.
  Columns: DEV / STAGE / PROD with colored status indicators.
  Confirm payments-service shows a red blocked indicator at STAGE.
  If missing services: `bash setup/bootstrap.sh --apptrust` to re-register.

---

## Fallback Ready

- [ ] **`jf audit` CLI fallback works for every service you plan to demo**
  Pre-run and save the output for quick copy-paste if the IDE is unresponsive:
  ```bash
  cd e2e/swiftship/auth-service && \
    jf audit --mvn --format json > /tmp/auth-service-audit.json

  cd e2e/swiftship/booking-service && \
    jf audit --pip --format json > /tmp/booking-service-audit.json

  cd e2e/swiftship/payments-service && \
    jf audit --nuget --format json > /tmp/payments-service-audit.json

  echo "Audit snapshots saved to /tmp/*-audit.json"
  ```

- [ ] **Loom recordings are accessible and ready**
  Open each recording link *now* and confirm it plays:
  - Stage A (IDE scan): _(paste Loom URL)_
  - Stage B (Curation block): _(paste Loom URL)_
  - Stage C (Frogbot PR): _(paste Loom URL)_
  - Stage D (AppTrust promotion + waiver): _(paste Loom URL)_
  - Stage E (ML/AI packages): _(paste Loom URL)_
  - Stage F (Runtime rollback): _(paste Loom URL)_

  Tip: open them in a separate browser tab and have them paused at 0:00 before the call.
  Do NOT share screen from the Loom tab — share it from your demo environment and only
  switch to Loom as a last resort so the customer sees live tooling.

---

**All boxes checked? You're ready. Get some sleep.**
