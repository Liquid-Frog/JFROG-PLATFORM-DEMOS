# SwiftShip E2E Demo — Full Talk Track

**Duration:** ~45 minutes  
**Audience:** Engineering leaders, DevSecOps practitioners, security teams  
**Goal:** Show how JFrog secures software from the developer's first keystroke
through runtime — using a realistic microservices platform (SwiftShip) that
spans Java, Python, Node.js, .NET, Go, and AI/ML.

**Before you begin:** Complete `e2e/PREP-CHECKLIST.md` the night before.
Have this document open in a second monitor or on your phone.

---

## Architecture at a Glance (keep this in your head)

SwiftShip has 8 services, each with deliberately seeded vulnerabilities:

| Service | Language | Key Demo Finding |
|---|---|---|
| auth-service | Java/Maven | CVE-2025-41234 RCE (CVSS 9.8, CISA KEV) |
| storefront-ui | Node.js/npm | CVE-2025-10894 Shai-Hulud supply chain |
| booking-service | Python/FastAPI | CVE-2025-3248 Langflow RCE (CISA KEV) |
| payments-service | .NET/NuGet | CVE-2024-21907 + AGPL iTextSharp |
| logistics-service | Go | CVE-2025-22869 stdlib smuggling |
| recommendation-engine | Python + HuggingFace | Unapproved ML model |
| ai-assistant | Python + MCP | Hardcoded API key + unapproved plugin |
| infra | Helm/OCI | IaC misconfigs (root container, priv-esc) |

The three promotion stages are: **DEV → STAGE → PROD**.  
The AppTrust Stages Board is where the demo reaches its climax.

---

## Opening — 2 minutes

**Screen:** Splash slide or the SwiftShip repo overview. No tools open yet.

> "We're going to walk through a day in the life of a fictional logistics
> company called SwiftShip. They're a mid-size engineering org — eight
> microservices, a mix of Java, Python, Node.js, .NET, and Go, plus a couple
> of experimental AI features. Sound familiar?
>
> What makes SwiftShip useful for this conversation is that it's realistic.
> Every security finding you'll see today came from a real CVE that was
> disclosed in the last 18 months. Two of them are on the CISA KEV list —
> exploited in the wild.
>
> In the next 45 minutes I'm going to show you the full lifecycle: how a
> vulnerability gets caught before it ever leaves a developer's laptop, what
> happens if it slips through to CI, how your promotion gates enforce policy
> without slowing teams down, and what happens if something makes it to
> production anyway.
>
> We'll start where a developer starts — in their IDE."

*What the customer is thinking: "OK, another tool demo. Let's see if this
is actually relevant to how my team works."*

---

## Stage A — IDE — 8 minutes

**Goal:** Show that Xray integrates into the developer's existing workflow
without changing how they work. Demo two IDE modes: VS Code extension
(traditional, no-prompt path) and Cursor/Claude Code (conversational, MCP
path).

### A1. VS Code — inline Xray scan (4 min)

**Screen:** VS Code with `e2e/swiftship/auth-service/pom.xml` open.

> "auth-service is the most critical service in SwiftShip — it's the JWT
> gateway that every other service depends on. If auth is compromised, the
> whole platform is compromised. Let me open the Maven POM."

**Click:** Open `e2e/swiftship/auth-service/pom.xml`.

> "Notice I haven't run any scanner, I haven't changed my workflow. This is
> just my normal editor. But watch what happens when I look at this
> dependency."

**Point to** `spring-core 6.1.6` (line ~50). There is already a red underline.
Hover over it.

> "CVE-2025-41234. CVSS 9.8. Remote code execution via serialized object
> injection. This is also on the CISA KEV list — meaning there is confirmed
> in-the-wild exploitation. The fix is to upgrade to spring-core 6.1.14 or
> later, and JFrog Xray found this the moment I opened the file.
>
> No context switch. No separate security scan step. The developer sees it
> *right here* in the file they're already editing."

**Scroll down slightly.** Point to `spring-security-core 6.2.3`.

> "And right below it: CVE-2025-41248 — authorization bypass, CVSS 9.1.
> An attacker who can't execute code on your server can bypass your entire
> auth layer. Two critical findings, side by side, in the dependency file
> where the developer already needs to be.
>
> This is the difference between security that's bolted on and security
> that's built in."

*What the customer is thinking: "We've seen IDE scanners before. But the
fact that it's CVE-specific, CVSS-scored, and inline — that's cleaner than
what we have today."*

**Fallback (if VS Code extension is not showing underlines):**
```bash
cd e2e/swiftship/auth-service
jf audit --mvn --extended-table
```
Show the terminal output on screen. Say: "In case anyone prefers the CLI,
same findings, same CVSS scores, same fix versions."

---

### A2. Cursor / Claude Code — MCP conversational mode (4 min)

**Screen:** Switch to Cursor, open `e2e/swiftship/` as the workspace.
MCP puzzle-piece icon should show "jfrog" as connected.

> "Now let me show you something newer. Some of your developers are using
> AI-assisted IDEs — Cursor, GitHub Copilot Workspace, Claude Code. The
> question I hear is: 'how do we govern what these AI tools know about our
> security posture?'
>
> JFrog ships an MCP server — a Model Context Protocol server — that connects
> your AI assistant directly to Xray. So instead of the AI giving generic
> advice about CVEs it read on the internet, it's querying *your* instance,
> *your* repositories, *your* findings."

**Type in Cursor Chat:**
```
@jfrog what CVEs are critical in the SwiftShip auth-service?
```

> "I'm asking the AI about *my codebase specifically*. Watch what it comes
> back with."

Wait for response (~5-10 seconds). It should return CVE-2025-41234 and
CVE-2025-41248 with their CVSS scores and fix versions.

> "The AI didn't hallucinate this. It called JFrog's API in real time.
> If I fix CVE-2025-41234 right now, the next query returns one finding
> instead of two. It's always current.
>
> Let me ask it something a security engineer would actually ask."

**Type:**
```
@jfrog which SwiftShip services have CISA KEV findings and what's the blast radius?
```

> "CISA KEV — the Known Exploited Vulnerabilities catalog — is the list of
> things you must fix first. The AI is now triaging across all eight services
> and pulling live Xray data. This is the kind of query that used to take a
> security engineer a day to build a spreadsheet for."

*What the customer is thinking: "OK that's actually different. The AI is
connected to real data, not generic CVE databases."*

**Fallback (if MCP is not responding):**
Switch back to VS Code. Say: "Let me show you the same data through the
Xray UI." Open the JFrog web UI → **Xray → Violations** → filter by
`swiftship-auth-service`. Walk through the findings table.

---

## Stage B — Curation — 5 minutes

**Goal:** Show that supply chain attacks are stopped *before* a package
reaches the developer's machine — not after. Use the Shai-Hulud campaign
as the real-world hook.

**Screen:** Terminal in `e2e/swiftship/storefront-ui/`.

> "One of the most dangerous attack vectors right now is the npm supply chain.
> In 2025 there was a campaign called Shai-Hulud — named after the sandworm
> in Dune, appropriately — where attackers embedded malicious code in minor
> version bumps of popular build tools. One of those packages was
> `@nx/devkit`. If a developer runs `npm install` today and pulls version
> 19.5.0, they get the malicious payload."

**Run this command:**
```bash
cd e2e/swiftship/storefront-ui
npm install @nx/devkit@19.5.0
```

> "Let's watch what happens when someone tries to install that version through
> the SwiftShip Artifactory repo."

The install should fail with a 403 and a message referencing Curation policy.

> "Blocked. The package never reached the developer's `node_modules`.
> It was stopped at the Artifactory layer — the single chokepoint that all
> package managers flow through. No alert fatigue, no 'please check your
> scanner results' email that nobody reads. The dependency is simply not
> available."

**Open JFrog UI:** **Curation → Audit**.

> "And here is the audit log. Time of the attempt, which user, which package,
> which policy fired. If I'm a security engineer, I can see every attempted
> install of every blocked package across the entire organization from this
> one screen.
>
> Let me show you what would have happened if we *hadn't* been using
> Curation."

**Open** `e2e/swiftship/storefront-ui/package.json`. Point to
`@nx/devkit: "19.5.0"` in the dependencies.

> "This is the package.json as the developer checked it in. The version is
> there. Without Curation, `npm install` would have succeeded, the malicious
> code would be in their node_modules, and the next build artifact would
> contain it. From that point forward, everything downstream — every Docker
> image, every deployment — is compromised.
>
> Curation is the answer to the question: 'how do we stop a supply chain
> attack before we even know it's happening?'"

*What the customer is thinking: "We've been relying on scanning images after
the fact. This is the first line of defense we're missing."*

**Fallback (if npm install is not blocked):**
Navigate to the JFrog UI → **Curation → Policies** and walk through the
policy configuration instead. Say: "Let me show you how the policy is
defined — the block happened because of this rule. Here's what the audit
log looks like in normal operation." Show pre-cached screenshot if available.

---

## Stage C — CI / Frogbot — 8 minutes

**Goal:** Show what happens when a vulnerability makes it past local dev
and reaches a pull request — and how Frogbot closes the loop automatically.

### C1. Frogbot PR Comment (3 min)

**Screen:** GitHub pull request for `demo/booking-service-vuln` branch.

> "OK, let's say a developer added Langflow to the booking-service for AI
> orchestration. They didn't scan locally. They pushed and opened a PR.
> This is the most common real-world scenario — security isn't caught by the
> developer, it's caught at CI."

**Show** the Frogbot comment in the PR. It should include a table of
vulnerabilities found in `booking-service/requirements.txt`.

> "Frogbot runs automatically on every pull request. It scans the dependency
> manifest, finds the Xray violations, and posts them directly in the PR
> comment — right where the developer is already working.
>
> Look at what it found: CVE-2025-3248. Langflow 1.1.4. Unauthenticated
> remote code execution. CVSS 9.8. This is also on the CISA KEV list.
>
> The developer doesn't have to run a scanner. They don't have to log into
> a security portal. The security context comes to them."

*What the customer is thinking: "My developers ignore security tickets because
they're out of context. This is in the PR — they can't ignore it."*

### C2. Auto-fix PR (2 min)

> "But Frogbot goes further than just reporting. If there's a safe upgrade
> path, it opens a fix PR automatically."

**Show** the Frogbot fix PR (or point to the "Create fix PR" button in the
Frogbot PR comment).

> "One click. Or zero clicks if you've configured auto-fix. The fix PR
> upgrades `langflow` from 1.1.4 to 1.3.0, which is the earliest clean
> version. The developer reviews it, approves it, and the vulnerability
> is gone.
>
> The entire remediation cycle — detect, assign, fix, verify — happens
> without leaving GitHub."

### C3. SBOM + AppTrust Version (3 min)

**Screen:** Terminal.

> "When this PR merges and CI builds the artifact, we need to capture
> what's in it. This is where the SBOM and AppTrust version come in."

```bash
# Show the CI command that generates the SBOM and creates the AppTrust version
# (this is what the GitHub Actions workflow runs automatically)
jf rt build-collect-env swiftship-booking-service 2.1.0
jf rt build-publish swiftship-booking-service 2.1.0 \
  --project $JFROG_PROJECT_KEY \
  --build-url "https://github.com/swiftship/demo/actions/runs/12345"

# The SBOM evidence is attached automatically on build publish
jf evd create \
  --evd-name cyclonedx-sbom \
  --package-name swiftship-booking-service \
  --package-version 2.1.0 \
  --package-type generic \
  --predicate sbom.json \
  --project $JFROG_PROJECT_KEY
```

> "Three commands — which the CI workflow runs automatically, not a human —
> and we now have a cryptographically signed SBOM attached to this exact
> build. We know what's in it, we can prove it hasn't been tampered with,
> and AppTrust just created a new Application Version for booking-service 2.1.0
> sitting at DEV.
>
> Let's go look at that in AppTrust."

**Open JFrog UI:** **AppTrust → Applications → swiftship-booking-service**.
Show the new version at DEV stage.

---

## Stage D — AppTrust Promotion — 10 minutes

**Goal:** Show the Stages Board, demonstrate a promotion blocked by real
policy, walk through the waiver workflow, and show a clean promotion — all
in sequence.

### D1. Stages Board Overview (2 min)

**Screen:** JFrog UI → **AppTrust → Stages Board**.

> "This is the Stages Board — the operational view of your entire software
> supply chain. Every one of SwiftShip's eight services is a row. The three
> columns are your promotion stages: Dev, Stage, and Prod.
>
> Healthy services are green. Services that are blocked from promotion are
> red. Services that have been promoted to Prod have a lock icon — immutable
> Release Bundle, can't be modified.
>
> Before I deploy anything to production, I can look at this screen and know
> exactly which services are clean and which ones have outstanding issues.
> This replaces the spreadsheet that most security teams are maintaining
> manually today."

*What the customer is thinking: "This is what I've been trying to build in
Jira. And it's automatic."*

### D2. payments-service — Blocked at Stage (3 min)

> "Let me click into payments-service. This is our most regulated service —
> it's in PCI-DSS scope, so it has the strictest lifecycle policy."

**Click** `swiftship-payments-service` on the Stages Board.

> "You can see it's blocked at the STAGE gate. Let's see why."

**Click** the red blocked indicator to expand the violation details.

> "Two violations. First: CVE-2024-21907 in Newtonsoft.Json 12.0.3 — a
> denial of service via deep JSON nesting. CVSS 7.5. The payments-strict
> policy blocks any CVE above 7.0 for this service, because PCI-DSS requires it.
>
> Second: iTextSharp 5.5.13.3 carrying an AGPL-3.0 license. AGPL is
> copyleft — if you ship a commercial payments product that links against AGPL
> software, you're required to open-source your entire payments codebase.
> That's a compliance violation, not just a security one."

*What the customer is thinking: "We have AGPL transitive deps that we don't
know about. This is real."*

### D3. Waiver Workflow (3 min)

> "Now here's where it gets interesting. The engineering team says: 'we know
> about the Newtonsoft.Json CVE. We can't migrate off it this sprint — we
> have a release deadline. Can we get a waiver?'
>
> In most organizations this would be an email chain. Maybe a Jira ticket.
> Probably a week of back-and-forth. Let me show you what it looks like in
> AppTrust."

**Click:** "Request Waiver" button on the CVE-2024-21907 violation.

Fill in the waiver form:
- **CVE:** CVE-2024-21907
- **Justification:** `Migration to Newtonsoft.Json 13.x blocked by DTO compatibility
  issues. Fix scheduled for payments-service v3.2 (2026-07-15).`
- **Expiry Date:** `2026-07-15`
- **Approved by:** (your name / security team group)

**Click** Submit, then Approve (if you have the security-team role).

> "The waiver is approved. It has a justification, an expiry date, and it
> creates an audit trail. Now let's try the promotion again."

**Click:** "Retry Promotion to Stage" on payments-service.

> "Watch what happens. The CVE violation is now waived — Frogbot and AppTrust
> both know it's acknowledged. But the AGPL violation —"

The promotion should fail again, this time only showing the license violation.

> "— is still blocking. This is intentional. The payments-strict Rego policy
> explicitly prohibits license waivers for copyleft in PCI-DSS scope. You can
> waive a security vulnerability if you have a plan to fix it. You cannot
> waive a license incompatibility. The dependency has to be replaced.
>
> Two different policy dimensions. One service. Both have to pass."

*What the customer is thinking: "This is audit-ready. I can show this to my
compliance team."*

**Fallback (if waiver UI is unavailable):**
Show the REST API equivalent:
```bash
curl -X POST "$JFROG_URL/apptrust/api/v1/waivers" \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "app_key": "swiftship-payments-service",
    "version": "1.0.0",
    "cve_id": "CVE-2024-21907",
    "justification": "Migration blocked by DTO compatibility. Fix in v3.2.",
    "expiry_date": "2026-07-15",
    "approved_by": "security-team"
  }'
```

### D4. logistics-service — Clean Promotion (2 min)

> "Let me show you what the happy path looks like. logistics-service is our
> Go routing service — its Xray findings were remediated last sprint."

**Click** `swiftship-logistics-service` on the Stages Board.

> "All green at Stage. The SBOM is present, Xray scan is complete with no
> blocking violations, the evidence is attached. Let's promote it."

**Click:** "Promote to Stage".

> "It goes through immediately. The Stages Board updates. You can see it move
> from DEV to STAGE in real time. If I then promote to PROD, Artifactory
> wraps the artifacts in a signed, immutable Release Bundle — it can never be
> modified after this point.
>
> That's the full promotion story: blocked where it needs to be blocked,
> clean where it should be clean, and an audit trail for everything."

---

## Stage E — ML / AI Packages — 7 minutes

**Goal:** Show that AI/ML assets (models, plugins) have the same governance
needs as traditional software — and that JFrog handles them.

### E1. HuggingFace Model Blocked by Curation (4 min)

**Screen:** Terminal in `e2e/swiftship/recommendation-engine/`.

> "SwiftShip's recommendation engine uses a HuggingFace model to power its
> personalization. Let me show you what happens when a data scientist tries to
> pull a model from an unapproved organization."

```bash
cd e2e/swiftship/recommendation-engine
# Show the Curation-blocked HuggingFace model download
python3 -c "
from huggingface_hub import hf_hub_download
# This org is not on the approved list — Curation blocks it
hf_hub_download(
    repo_id='community-user/swiftship-rec-v2',
    filename='pytorch_model.bin',
    cache_dir='/tmp/hf-test'
)
" 2>&1 | head -20
```

The download should be blocked by the Curation proxy.

> "Blocked. Same mechanism as the npm block — every package manager, including
> the HuggingFace Hub client, is routed through Artifactory. The Curation
> policy says: models are only allowed from approved organizations on our
> model registry whitelist. `community-user` is not on that list.
>
> Why does this matter? A malicious model can do everything a malicious npm
> package can do — and it's harder to detect because model weights are binary.
> You can't grep a `.bin` file. Curation is the only layer where you can
> enforce this before it lands in your environment."

*What the customer is thinking: "We have no governance on our HuggingFace
downloads at all right now. This is a gap."*

**Open JFrog UI:** **Curation → Audit**, filter by package type "huggingface".

> "And again — every blocked model pull is logged here. You know who tried
> to download what, when, and from which machine."

**Fallback (if HuggingFace Curation is not configured):**
Open the Curation policy config in the UI. Say: "Let me walk you through
how the policy is defined — you can see we've specified approved orgs and
the block applies to any model pull not from that list. This is what the
audit log looks like in production."

### E2. Agent Plugin Governance (3 min)

**Screen:** Open `e2e/swiftship/ai-assistant/app/config.py`.

> "Now for something most security teams haven't thought about yet. AI
> assistants — tools like Cursor, Claude Code, GitHub Copilot — are running
> plugins that have full read access to your source code. Sometimes write
> access. The plugin registry is the new npm registry, and it has the same
> supply chain risk.
>
> Look at the AI assistant service config."

**Point to** the `PLUGIN_REGISTRY_URL` in `config.py` — it references an
unapproved Cursor plugin registry.

> "This is JFrog's JAS Secrets detection flagging a different kind of secret:
> not a password, but a registry URL that points outside our approved package
> ecosystem. Any plugin installed from that registry bypasses our Curation
> policies entirely.
>
> In AppTrust, the ai-assistant service has an AI-specific lifecycle policy
> that requires evidence of plugin provenance before it can be deployed.
> Let me show you that in the Stages Board."

**Open AppTrust UI:** Click `swiftship-ai-assistant`.

> "Blocked at Stage. The policy says: before this AI service can promote to
> Stage, it needs a signed evidence item attesting that all plugins came from
> the approved JFrog Agent Plugins repository. That evidence doesn't exist
> yet because config.py is pointing at an external registry.
>
> The fix is: point at Artifactory, rebuild, resubmit. Your AI tooling
> governed by the same policy framework as everything else."

---

## Stage F — Runtime — 5 minutes

**Goal:** Show that security doesn't stop at deployment — and demonstrate
how AppTrust and Xray work together when a new CVE is disclosed after
a service is already running in production.

**Screen:** JFrog UI → **AppTrust → Runtime** (or **Xray → Watches**).

> "Everything I've shown you so far happens before deployment. But what
> happens when a new CVE is published for a package that's *already running
> in production*?
>
> This is the scenario that keeps security engineers up at night. You've
> done everything right — you scanned, you promoted, you have a Release
> Bundle. And then NVD publishes CVE-2025-22871 for the Go stdlib version
> that's in your logistics service."

**Open:** AppTrust → Runtime view → filter for `swiftship-logistics-service`.

> "AppTrust has a continuous watch on deployed versions. When Xray's
> vulnerability feed ingests the new CVE, it re-evaluates every Release
> Bundle that contains the affected package version. The logistics-service
> PROD deployment lights up red — even though it was green when we promoted it."

**Point to** the alert on logistics-service.

> "The team gets notified. Now they have a decision: is this CVE exploitable
> in the context of how we use the package? CVSS 7.5 — it's a denial of
> service via HTTP request smuggling in the Go stdlib net/http package.
>
> For a public-facing logistics API, that's a real risk. The response is:
> roll back to the previous Release Bundle while the fix is developed."

**Click:** "Rollback to previous version" (or show the CLI equivalent):
```bash
jf release-bundle distribute \
  swiftship-logistics-service 1.0.0 \
  --project $JFROG_PROJECT_KEY \
  --site-name production-cluster \
  --create-repo false
```

> "One command. The previous Release Bundle — which was already distributed
> to production — is re-deployed. The immutability guarantee means we know
> exactly what's in that previous bundle. There's no 'what was in v1.0.0
> again?' question. It's signed, it's the same bits as last time.
>
> This is the full loop: detected at IDE, blocked at Curation, flagged at
> CI, gated at promotion, monitored at runtime, rolled back when needed.
>
> That's the JFrog platform."

*What the customer is thinking: "I've seen bits of this story from other
vendors. I've never seen the full loop in one platform."*

**Fallback (if Runtime view is not populated):**
Use the Xray Watches violation notification instead. Open
**Xray → Watches → `${JFROG_REPO_PREFIX}-watch` → Violations** and show
the logistics-service finding. Say: "The watch fires when a new CVE
is indexed against an artifact that's already been published. The Runtime
view gives you the deployed-state context — which environment, which cluster,
which version is actually running. The underlying data is the same."

---

## Closing — 2 minutes

**Screen:** Back to Stages Board — all 8 services visible.

> "Let me leave you with this screen. Eight services. Three stages. Every
> finding we surfaced today — the Spring RCE in auth, the supply chain attack
> in storefront, the CISA KEV finding in booking, the license violation in
> payments, the unapproved HuggingFace model, the rogue plugin registry,
> the post-deployment CVE in logistics — all of it is visible here, with
> policy enforced automatically at every boundary.
>
> The question I always get is: 'doesn't this slow teams down?' What actually
> slows teams down is finding these problems in production. Catching CVE-2025-41234
> in the IDE takes a developer 30 seconds to understand and 5 minutes to fix.
> Finding it after deployment costs you an incident response, a customer
> notification, maybe a regulatory filing.
>
> What would you like to dig into? We can go deeper on the waiver workflow,
> the Rego policies, the SBOM evidence chain, or the ML governance — wherever
> is most relevant to what your team is working on right now."

---

## Appendix: Timing Reference

| Stage | Content | Time |
|---|---|---|
| Opening | Context and agenda | 2 min |
| A — IDE | VS Code inline + Cursor MCP | 8 min |
| B — Curation | Shai-Hulud npm block | 5 min |
| C — CI/Frogbot | PR comment, fix PR, SBOM, version | 8 min |
| D — AppTrust | Stages Board, blocked, waiver, clean | 10 min |
| E — ML/AI | HuggingFace block, plugin governance | 7 min |
| F — Runtime | New CVE alert, rollback | 5 min |
| **Total** | | **45 min** |

Add 5 minutes of buffer before the closing call-to-action for questions
that come up mid-demo. If you're running over, cut Stage F (it's the most
dependent on a live runtime environment) and describe the rollback scenario
verbally.

---

## Quick Reference: Key CVEs

| CVE | Package | CVSS | Severity | Demo Stage |
|---|---|---|---|---|
| CVE-2025-41234 | spring-core 6.1.6 | 9.8 | Critical (CISA KEV) | A — IDE |
| CVE-2025-41248 | spring-security-core 6.2.3 | 9.1 | Critical | A — IDE |
| CVE-2025-10894 | @nx/devkit 19.5.0 | — | Supply chain | B — Curation |
| CVE-2024-21538 | cross-spawn 7.0.3 | 7.5 | High | B — Curation |
| CVE-2025-3248 | langflow 1.1.4 | 9.8 | Critical (CISA KEV) | C — CI |
| CVE-2024-47874 | starlette 0.36.3 | 8.7 | High | C — CI |
| CVE-2024-21907 | Newtonsoft.Json 12.0.3 | 7.5 | High | D — AppTrust |
| AGPL-3.0 | iTextSharp 5.5.13.3 | — | License violation | D — AppTrust |
| CVE-2025-22869 | golang.org/x/crypto | 7.5 | High | F — Runtime |
| CVE-2025-22871 | Go stdlib net/http | 7.5 | High | F — Runtime |

## Quick Reference: JFrog UI Navigation

| What to open | Where |
|---|---|
| Stages Board | AppTrust → Stages Board |
| Curation Audit | Curation → Audit |
| Xray Violations | Xray → Violations (filter by Watch) |
| Xray Watches | Xray → Watches |
| AppTrust Applications | AppTrust → Applications |
| AppTrust Runtime | AppTrust → Runtime |
| Release Bundles | Distribution → Release Bundles |
| Build info / SBOM | Artifactory → Builds |
