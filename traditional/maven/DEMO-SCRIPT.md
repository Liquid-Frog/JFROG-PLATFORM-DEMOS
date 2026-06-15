# Demo Script — Maven

**Time:** ~10 minutes
**Mode:** Plugin (VS Code / IntelliJ) → CLI → AppTrust Stages Board
**Product coverage:** Xray · JAS · AppTrust promotion gate · Frogbot
**Key CVEs:** CVE-2025-41234 (Spring Framework RCE, CVSS 9.8) · CVE-2025-41248 (Spring Security bypass, CVSS 9.1)

---

## Before you start

```bash
./setup/validate.sh                # verify instance is connected
./setup/prep.sh --service auth     # seed vulnerable Maven artifacts
cd traditional/maven
./demo.sh --reset                  # clean demo state
```

Open `traditional/maven/sample-app/` in IntelliJ IDEA or VS Code with the JFrog extension.

**Requires:** JDK 17+, Maven 3.8+ (or demo degrades gracefully — `jf audit` still runs without a build)

---

## Step 1 — Developer discovers the CVE at IDE time

**What to do:** Open `traditional/maven/sample-app/pom.xml` in IntelliJ.

**What to say:**
> "I've opened this Maven project in IntelliJ with the JFrog plugin. Before I build
> anything, I can already see CVE-2025-41234 highlighted on the `spring-core 6.1.6`
> dependency line. This is a Critical-severity Remote Code Execution vulnerability —
> CVSS 9.8. It affects Spring Framework 6.0.x through 6.1.13 and allows an attacker
> to traverse the application's directory structure and achieve code execution via a
> crafted HTTP request.
>
> We also see CVE-2025-41248 on spring-security-core 6.2.2 — a CVSS 9.1 authorization
> bypass. These two together mean: anyone who can reach this service over the network
> could both bypass authentication AND run arbitrary code. That's why this service
> runs under the AppTrust 'strict' policy — CVSS >= 7.0 is a hard block."

**Expected output:** Red annotations on `<spring-framework.version>6.1.6</spring-framework.version>` and `<spring-security.version>6.2.2</spring-security.version>` in pom.xml.

**MCP variant:**
> Type: *"Is CVE-2025-41234 reachable in this codebase?"*
> Expected: JFrog MCP returns the CVE details, affected packages, and notes that
> `/api/files/{filename}` in App.java is the exposed attack surface.

---

## Step 2 — CI build deploys vulnerable jar to dev repo

**What to do:** Run `./demo.sh` (or manually):

```bash
cd traditional/maven/sample-app
jf mvn-config \
  --repo-resolve-releases="${JFROG_REPO_PREFIX}-maven-dev" \
  --repo-deploy-releases="${JFROG_REPO_PREFIX}-maven-dev" \
  --server-id-resolve=swiftship \
  --server-id-deploy=swiftship

jf mvn deploy -DskipTests \
  --build-name=swiftship-auth-service-demo \
  --build-number=1
```

**What to say:**
> "Here's what happens in CI. The build resolves spring-core 6.1.6 from JFrog's
> Maven repository — that artifact was already indexed by Xray the moment it was
> cached. The jar is deployed to the dev repository. JFrog records the build
> information: which artifacts, which dependencies, which build number. That build
> info is what links this jar to its Xray scan results and eventually to its
> AppTrust Application version."

**Expected output:** Maven build succeeds; jar uploaded to `demo-maven-dev`.

---

## Step 3 — Xray flags CVE-2025-41234 (Spring RCE)

**What to do:** Run `jf audit --mvn` or show the Xray Violations tab in the UI.

```bash
jf audit --mvn --format=table
```

**What to say:**
> "Here are the Xray findings for this build. CVE-2025-41234 — CVSS 9.8 Critical.
> Spring Framework 6.1.6. Remote Code Execution via path traversal in the web layer.
>
> But notice Xray doesn't just tell me 'there's a CVE'. It tells me the fixed version,
> the full dependency path through the Maven tree, and — with JAS enabled — the
> reachability analysis. Can this vulnerability actually be exploited in THIS
> application? Xray traces the call graph from the vulnerable Spring method to see
> if our code calls it. In this case: yes. The `/api/files/{filename}` endpoint in
> App.java calls through the vulnerable path. This is a reachable, exploitable
> finding."

**Expected output:**
```
┌─────────────────┬────────────┬───────────────────────────────┐
│ CVE             │ CVSS Score │ Package                       │
├─────────────────┼────────────┼───────────────────────────────┤
│ CVE-2025-41234  │ 9.8        │ org.springframework:spring-core:6.1.6  │
│ CVE-2025-41248  │ 9.1        │ org.springframework.security:spring-security-core:6.2.2 │
└─────────────────┴────────────┴───────────────────────────────┘
```

**JAS reachability angle:** Click into CVE-2025-41234 in the Xray UI and show the
"Contextual Analysis" / "Reachability" tab. If JAS is enabled, it will confirm
the vulnerability is reachable via `App.serveFile()`.

---

## Step 4 — Stage promotion blocked by AppTrust policy

**What to do:** Attempt to promote to Stage from the AppTrust Stages Board or CLI:

```bash
jf apptrust version-promote swiftship-auth-service 1.0.0 STAGE \
  --sync=true \
  --server-id=swiftship
```

**What to say:**
> "This is where the rubber meets the road. The security team doesn't have to ask
> developers to fix this — the AppTrust lifecycle policy enforces it. I'm trying to
> promote version 1.0.0 of the auth-service to Stage. The Stage gate policy is:
> 'block on CVSS >= 7.0'. Spring RCE at 9.8? Hard stop.
>
> The promotion is rejected. The auth-service cannot reach customers. The violation
> is logged in AppTrust — who tried the promotion, when, what policy fired. That's
> your audit trail. Not a ticket, not a Confluence page — it's in the platform that
> owns the artifact."

**Expected output:**
```
Promotion BLOCKED: CVE-2025-41234 (CVSS 9.8) violates the lifecycle policy
payments-strict: min_cvss_threshold = 7.0
The following findings must be resolved or waived before promotion to STAGE.
```

**AppTrust Stages Board (UI):** Open `swiftship-auth-service` in the AppTrust UI
and show the red gate indicator on the DEV → STAGE transition.

---

## Step 5 — Fixed version promotes cleanly

**What to do:** Update pom.xml to use fixed versions:

```xml
<!-- In <properties>: -->
<spring-framework.version>6.1.14</spring-framework.version>
<spring-security.version>6.3.4</spring-security.version>
```

Then rebuild and re-promote:

```bash
jf mvn deploy -DskipTests --build-name=swiftship-auth-service-demo --build-number=2
jf audit --mvn --format=table    # should be clean
jf apptrust version-promote swiftship-auth-service 1.0.1 STAGE --sync=true
```

**What to say:**
> "The fix is a one-line change in pom.xml — bump spring-core from 6.1.6 to 6.1.14.
> That's the patch Spring released for CVE-2025-41234. Rebuild, scan — clean. The
> AppTrust gate passes. Version 1.0.1 is in Stage.
>
> And here's the chain of custody you get for free: Xray scan results, SBOM, build
> information, promotion history — all linked to version 1.0.1 in AppTrust. When your
> compliance team asks 'how do you know this production artifact is clean?', you open
> AppTrust and show them this view."

**Expected output:** `jf audit --mvn` returns no findings. Stage promotion succeeds.
AppTrust shows 1.0.1 in Stage with a green gate.

---

## Talking points

- **CVSS 9.8 in a Spring app:** "Spring Framework is in literally every Java web service. This isn't a niche library. Every Java shop has spring-core in their dependency tree."
- **Reachability (JAS):** "Traditional SCA shows you all CVEs. JAS shows you which ones are actually reachable in your specific code. That's the signal vs. noise difference."
- **The gate doesn't lie:** "You can ignore a Slack alert. You can close a Jira ticket. You cannot bypass an AppTrust lifecycle gate without a logged waiver approved by the security team."
- **Audit trail:** "Every promotion attempt, every waiver, every approval — immutably recorded. This is what your auditor wants to see."

---

## Frogbot talking point

Open the GitHub repo and show the Frogbot PR on the `main` branch:
> "When the engineer submitted this code, Frogbot automatically opened a fix PR —
> upgrading spring-core to 6.1.14. One click to merge. The developer never left GitHub,
> never filed a Jira ticket, never emailed security. The remediation happened inside
> the normal development workflow."

---

## Fallback (if Maven build fails — JDK not available)

```bash
cd traditional/maven/sample-app
jf audit --mvn
```

`jf audit` reads the pom.xml directly without building — shows the same CVE findings
without needing a JDK or Maven installation.
