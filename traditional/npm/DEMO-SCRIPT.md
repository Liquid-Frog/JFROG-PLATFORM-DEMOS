# Demo Script — npm

**Time:** ~10 minutes
**Mode:** Plugin (VS Code / IntelliJ) → CLI → MCP
**Product coverage:** Curation · Xray · JAS · Frogbot · AppTrust promotion
**Key CVEs:** CVE-2024-21538 (cross-spawn ReDoS, CVSS 7.5) · CVE-2025-10894 (Shai-Hulud supply chain)

---

## Before you start

```bash
./setup/validate.sh                    # verify instance is connected
./setup/prep.sh --service storefront   # seed vulnerable npm packages
cd traditional/npm
./demo.sh --reset                      # clean demo state
```

Open `traditional/npm/sample-app/` in VS Code with the JFrog extension installed.

---

## Step 1 — Developer discovers the CVE at IDE time

**What to do:** Open `traditional/npm/sample-app/package.json` in VS Code.

**What to say:**
> "Before I even run a build, the JFrog extension is already telling me there's a
> problem. I've got CVE-2024-21538 — CVSS 7.5 — in cross-spawn 7.0.3. This is the
> shift-left catch. The cost to fix a vulnerability at IDE time versus production is
> orders of magnitude lower. Notice I haven't run a single command yet. JFrog
> connected to my instance in the background and pulled the scan results the moment
> I opened this file."

**Expected output:** Red/orange annotation on line `"cross-spawn": "7.0.3"`.

**MCP variant (Cursor / Claude Code):**
> Type: *"What CVEs are critical in this project?"*
> Expected: JFrog MCP returns CVE-2024-21538 with CVSS 7.5, affected path
> `node_modules/cross-spawn`, and a fix suggestion of 7.0.5.

---

## Step 2 — Publish vulnerable package to dev repo

**What to do:** Run `./demo.sh` (or the step manually):

```bash
cd traditional/npm
jf npmc \
  --repo-resolve="${JFROG_REPO_PREFIX}-npm-dev" \
  --repo-deploy="${JFROG_REPO_PREFIX}-npm-dev" \
  --server-id-resolve=swiftship \
  --server-id-deploy=swiftship

cd sample-app
jf npm install --no-fund --no-audit
jf npm publish --server-id=swiftship
```

**What to say:**
> "I've configured npm to resolve and publish through JFrog. When my CI pipeline
> runs npm install, every package that gets pulled — including cross-spawn 7.0.3 —
> is cached in Artifactory and immediately indexed by Xray. There's no agent to
> install, no side-car process. The moment an artifact enters my binary repository,
> JFrog knows about it."

**Expected output:** JFrog CLI shows packages downloaded from Artifactory; publish succeeds.

---

## Step 3 — Xray flags CVE-2024-21538 (cross-spawn ReDoS)

**What to do:** Run `jf audit --npm` or observe the Xray Violations tab.

```bash
jf audit --npm --format=table
```

**What to say:**
> "Here's the Xray finding. CVE-2024-21538 — a Regular Expression DoS in cross-spawn
> 7.0.3. CVSS 7.5. The attack vector is network-reachable — any input that a user can
> control, like a shipping address or a filename, could be used to freeze the process
> with a crafted string. Xray is showing me the fix: upgrade to 7.0.5. One line change
> in package.json."

**Expected output:**
```
┌─────────────────┬────────────┬─────────────────────────────────────────────────────────────────────────────┐
│ CVE             │ CVSS Score │ Package                                                                     │
├─────────────────┼────────────┼─────────────────────────────────────────────────────────────────────────────┤
│ CVE-2024-21538  │ 7.5        │ cross-spawn:7.0.3                                                           │
└─────────────────┴────────────┴─────────────────────────────────────────────────────────────────────────────┘
```

**Talking point:** Show the Xray violations view in the UI — click through to see
the full CVE description, affected components graph, and the CVSS vector string.

---

## Step 4 — Curation blocks Shai-Hulud supply-chain attack (CVE-2025-10894)

**What to do:** Attempt to install `@nx/devkit@19.5.0`:

```bash
cd traditional/npm/sample-app
jf npm install @nx/devkit@19.5.0 --no-fund
```

**What to say:**
> "Now watch this. I'm going to try to install `@nx/devkit@19.5.0`. This version
> was part of a well-known supply-chain attack — one of its transitive dependencies
> was compromised to run malicious code at install time. The malicious package, which
> the security community nicknamed 'Shai-Hulud', would have exfiltrated your CI/CD
> environment variables — your cloud credentials, your API tokens — the moment
> `npm install` ran.
>
> But JFrog Curation stopped it. Before the package was even downloaded to my
> machine, JFrog checked its provenance against our Curation policies. The policy
> fired: 'block packages with known malicious behaviour'. The install failed with a
> 403. That package never touched my filesystem."

**Expected output:**
```
npm error 403 Forbidden: @nx/devkit@19.5.0
npm error JFrog Curation Policy violation: CVE-2025-10894 — malicious package blocked
```

**Talking point (if it doesn't block):**
> "Curation needs to be enabled and policies need to be configured. Let me show you
> the policy that would fire: [open Curation policies in the UI]."

---

## Step 5 — Fixed version passes all gates

**What to do:** Update `package.json` to use `cross-spawn 7.0.5` and re-run the audit:

```bash
# Update in package.json:
# "cross-spawn": "7.0.5"

jf npm install --no-fund --no-audit
jf audit --npm --format=table
```

**What to say:**
> "Here's the same package with cross-spawn bumped to 7.0.5 — the patch that fixes
> CVE-2024-21538. Xray audit comes back clean. No findings above our threshold of
> 7.5. The AppTrust Stage gate will pass. This version can ship.
>
> And look at the audit trail: Xray logged the vulnerable 1.0.0, it logged the
> Curation block on the @nx/devkit install, it logged the clean 1.0.1 scan. When
> a security team wants to know 'why did we ship this?' or 'when did we know about
> that CVE?', that audit trail is right there in Artifactory — not in a spreadsheet,
> not in a separate tool."

**Expected output:** `jf audit --npm` returns zero findings at CVSS >= 7.5.

---

## Talking points

- **Shift left:** "We found CVE-2024-21538 at IDE time — before any `npm install` ran."
- **Curation is pre-emptive:** "Shai-Hulud never touched the network. Traditional scanners run *after* install — they would have seen it, but only after it ran."
- **One platform:** "Curation, Xray, IDE plugin, CI gate, promotion audit trail — all the same JFrog instance, same data, no stitching together separate tools."
- **Supply chain vs CVEs:** "Cross-spawn is a known CVE — a public vulnerability in a legitimate package. Shai-Hulud is a malicious package — it has no CVE because it was designed to be malicious. JFrog catches both categories."

---

## Frogbot talking point

> "When this PR was opened on GitHub, Frogbot automatically scanned it, found
> CVE-2024-21538 in the diff, and created a fix PR — upgrading cross-spawn from
> 7.0.3 to 7.0.5. The developer merges a single PR. The whole workflow is inside
> GitHub."

Open the GitHub repo and show the Frogbot PR comment and fix PR.

---

## Fallback (if IDE / MCP / npm install fails)

```bash
cd traditional/npm/sample-app
jf audit
```

This works regardless of npm configuration and shows the same CVE findings from the manifest file.

---

## AppTrust demo hook

After step 5, show the AppTrust Stages Board for `swiftship-storefront-ui`:
- **Dev**: contains the vulnerable 1.0.0 — violations visible, promotion blocked
- **Stage**: receives the fixed 1.0.1 — gate passes, SBOM attached
- **Prod**: clean release bundle, signed, immutable

```bash
jf apptrust version-promote swiftship-storefront-ui 1.0.1 STAGE --sync true
```
