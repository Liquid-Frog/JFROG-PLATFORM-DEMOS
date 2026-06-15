# AppTrust Configuration — SwiftShip

Config-as-code for all eight SwiftShip microservices. Covers Application definitions,
the three-stage lifecycle, and the Rego policies that gate each promotion.

---

## File map

```
e2e/apptrust/
├── applications.yaml                      # All 8 AppTrust Application definitions
├── stages-board.yaml                      # Dev → Stage → Prod lifecycle config
├── lifecycle-policies/
│   ├── payments-strict.rego               # Blocks CVSS >= 7 + GPL/AGPL (waivers OK for CVEs)
│   └── standard.rego                      # Blocks CVSS >= 9 to Prod; warns on >= 7
└── README.md                              # This file
```

---

## Prerequisites

| Requirement | Version |
|---|---|
| JFrog CLI | v2.81.0 or later |
| Artifactory | Enterprise+ v7.125.x or later |
| Xray | v3.130.5 or later |
| AppTrust | Enabled on your instance (`Settings → AppTrust`) |

Verify your instance before starting:

```bash
./setup/validate.sh
```

---

## Applying the configuration

### Step 1 — Bootstrap Artifactory repos and Xray policies

The Rego policies reference Xray policies by name (e.g. `demo-dev-policy`).
Create them first:

```bash
./setup/bootstrap.sh
```

### Step 2 — Create AppTrust Applications

Each entry in `applications.yaml` maps to one `jf apptrust app-create` call.
`bootstrap.sh --apptrust` loops over the file, but you can also apply one at a time:

```bash
# Create a single application from the spec (using yq to extract one entry)
APP_KEY=swiftship-auth-service
yq eval ".applications[] | select(.app_key == \"$APP_KEY\") | del(.app_key)" \
  e2e/apptrust/applications.yaml > /tmp/${APP_KEY}-spec.yaml

jf apptrust app-create "$APP_KEY" \
  --project "$JFROG_PROJECT_KEY" \
  --spec /tmp/${APP_KEY}-spec.yaml

# Or create all eight at once:
./setup/bootstrap.sh --apptrust
```

The `criticality` and `maturity_level` values map directly to AppTrust fields:

| Field | Allowed values |
|---|---|
| `criticality` | `low` `medium` `high` `critical` |
| `maturity_level` | `experimental` `production` `end_of_life` |

Demo-specific metadata (`package_type`, `policy_profile`, `team`) is stored in
`labels` — visible in the AppTrust UI and filterable via the REST API.

### Step 3 — Create the Stage lifecycle stage

AppTrust creates `DEV` and `PROD` by default.
The intermediate `STAGE` stage must be added:

```bash
curl -s -X POST "$JFROG_URL/apptrust/api/v1/lifecycle-stages" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "STAGE", "category": "Promote"}'
```

Verify via the AppTrust UI: **Applications → [app] → Lifecycle → Stages**.

### Step 4 — Register Rego lifecycle policies

Upload the Rego policies to AppTrust via the REST API:

```bash
# payments-strict policy
curl -s -X POST "$JFROG_URL/apptrust/api/v1/lifecycle-policies" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"payments-strict\",
    \"description\": \"Blocks CVSS >= 7 and GPL/AGPL licenses for payments services\",
    \"policy_content\": $(jq -Rs . < e2e/apptrust/lifecycle-policies/payments-strict.rego)
  }"

# standard policy
curl -s -X POST "$JFROG_URL/apptrust/api/v1/lifecycle-policies" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"standard\",
    \"description\": \"Blocks CVSS >= 9 to Prod; warns on CVSS >= 7\",
    \"policy_content\": $(jq -Rs . < e2e/apptrust/lifecycle-policies/standard.rego)
  }"
```

### Step 5 — Register an Application Version and promote it

```bash
APP_KEY=swiftship-payments-service
VERSION=1.2.0

# Bind the NuGet packages published to the dev repo
jf apptrust version-create "$APP_KEY" "$VERSION" \
  --source-type-packages "type=NuGet, name=SwiftShip.Payments, version=$VERSION, repo-key=${JFROG_REPO_PREFIX}-nuget-dev" \
  --tag="sprint-47"

# Promote to Stage (gate evaluation fires here — expect a block from payments-strict)
jf apptrust version-promote "$APP_KEY" "$VERSION" STAGE --sync true

# After waiver approved, re-promote:
jf apptrust version-promote "$APP_KEY" "$VERSION" STAGE --sync true

# Promote to Prod (second hard gate)
jf apptrust version-promote "$APP_KEY" "$VERSION" PROD --sync true --promotion-type copy
```

---

## Policy profiles reference

| Profile | Services | Block threshold | License check | Waivers |
|---|---|---|---|---|
| `strict` | auth-service, payments-service | CVSS >= 7.0 | No GPL/AGPL | CVE waivers only |
| `payments-strict` | payments-service | CVSS >= 7.0 | No GPL/AGPL/GPL | CVE waivers only; license violations cannot be waived |
| `standard` | storefront-ui, booking-service, logistics-service | CVSS >= 9.0 (Prod); warn >= 7.0 | Informational | Not applicable |
| `ml-specific` | recommendation-engine | Inherits standard + model provenance evidence | Informational | Not applicable |
| `ai-specific` | ai-assistant | Inherits standard + plugin registry evidence | Informational | Not applicable |
| `iac-specific` | infra | IaC misconfig block + standard CVE thresholds | Informational | Not applicable |

---

## How the Stages Board maps to the SwiftShip demo narrative

The three-stage board is the backbone of the live demo. Each stage is a
chapter in the story:

### Chapter 1 — Dev (the discovery)

> "Let's look at what Xray found in the developer's environment."

- Open `e2e/swiftship/auth-service` in VS Code with the JFrog extension loaded.
- Show CVE-2025-41234 (Spring RCE, CVSS 9.8) highlighted inline.
- Show that the finding is **warning only** at Dev — the developer isn't blocked.
- Click through to the Xray detail view: reachability analysis, exploit maturity,
  CISA KEV tag (if applicable).

### Chapter 2 — Stage (the gate)

> "What happens when the team tries to ship this to customers?"

- Trigger `jf apptrust version-promote swiftship-payments-service 1.2.0 STAGE`.
- The promotion is **blocked**. Two findings fire in `payments-strict.rego`:
  1. CVE-2024-21907 (Newtonsoft.Json, CVSS 7.5) — above the 7.0 threshold.
  2. iTextSharp AGPL-3.0 license — prohibited in PCI-DSS scope.
- The owning team receives a Slack notification (if `SLACK_WEBHOOK_URL` is set).
- Show the AppTrust UI: violation details, the Rego rule that fired, the owner group.

**The waiver sub-plot** *(optional, ~3 min)*:

- Engineer submits a waiver for CVE-2024-21907: "iTextSharp migration is Q3 — can't
  ship this week without the Newtonsoft fix." Security team approves with a 90-day expiry.
- Re-run the promotion: CVE-2024-21907 is now **waived** (warn logged, not blocked).
- The AGPL violation **still blocks** — license violations cannot be waived.
- Key message: *"Security and compliance are independent gates. A CVE waiver doesn't
  help you with a license violation."*

### Chapter 3 — Prod (the release)

> "Once the team fixes the remaining issue, how does the release actually ship?"

- Engineer replaces iTextSharp with a commercially-licensed PDF library.
- New version `1.3.0` promoted through Stage (clean) → Prod.
- `--promotion-type copy` preserves the Stage artefacts immutably.
- A signed Release Bundle is created: `jf apptrust version-release swiftship-payments-service 1.3.0`.
- Show the AppTrust Releases view: immutable, signed, full audit trail from Dev through Prod.

---

## Waiver workflow

```bash
# 1. Create a waiver request (via AppTrust REST API)
curl -s -X POST "$JFROG_URL/apptrust/api/v1/waivers" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"app_key\": \"swiftship-payments-service\",
    \"cve_id\": \"CVE-2024-21907\",
    \"justification\": \"Newtonsoft.Json migration is planned for Q3 — cannot delay this sprint release.\",
    \"expiry_date\": \"2026-09-30\",
    \"requested_by\": \"$JFROG_USER\"
  }"

# 2. Approve the waiver (security-team member)
curl -s -X PUT "$JFROG_URL/apptrust/api/v1/waivers/{waiver-id}/approve" \
  -H "Authorization: Bearer $JFROG_TOKEN"

# 3. Re-run the promotion gate — waiver is now reflected in input.approved_waivers
jf apptrust version-promote swiftship-payments-service 1.2.0 STAGE --sync true
```

The `is_waived()` helper in `payments-strict.rego` checks `input.approved_waivers[]`
at evaluation time. When the waiver is present, the CVE deny rule does not fire
but the `warn` rule does — preserving the audit trail.

---

## Links

- [JFrog AppTrust docs](https://docs.jfrog.com/governance/docs/jfrog-apptrust)
- [AppTrust Quickstart](https://docs.jfrog.com/governance/docs/apptrust-quickstart)
- [JFrog CLI — AppTrust commands](https://docs.jfrog.com/governance/docs/apptrust-cli)
- [OPA Rego language reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [JFrog Evidence Service](https://docs.jfrog.com/governance/docs/evidence-service)
