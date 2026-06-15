# Demo script — REPLACE_PACKAGE_TYPE

**Time:** ~10 minutes  
**Mode:** Plugin (VS Code / IntelliJ) or MCP (Cursor / Claude Code) or CLI fallback  
**Product coverage:** Artifactory · Xray · Curation · JAS · Frogbot · AppTrust promotion

---

## Before you start

Run the night-before checklist:
```bash
./setup/validate.sh        # verify everything is connected
./setup/prep.sh            # seed vulnerable packages into sandbox
```

Open `traditional/REPLACE_PACKAGE_TYPE/sample-app/` in your IDE.

---

## Step 1 — Developer discovers the CVE at IDE time

**What to do:** Open the package manifest (`REPLACE_MANIFEST_FILE`) in VS Code or IntelliJ.

**What to say:**
> "Before I even run a build, the JFrog extension is already telling me there's a problem. I've got [CVE-ID] — CVSS [SCORE] — in [PACKAGE]. This is a shift-left catch. The cost to fix a vulnerability at IDE time versus production is orders of magnitude lower."

**Expected output:** Red/orange inline annotation on the vulnerable dependency line.

**MCP variant (Cursor / Claude Code):**
> Type: "What CVEs are critical in this project?"  
> Expected: JFrog MCP returns live Xray data with CVE IDs, CVSS scores, and fix versions.

---

## Step 2 — Curation blocks the bad package

**What to do:** In a terminal inside sample-app, run the install command for the vulnerable package:
```bash
# REPLACE with package-type-specific install command
```

**What to say:**
> "Watch what happens when I try to install this package. JFrog Curation stops it before it even hits my filesystem. The policy here is blocking anything in the CISA Known Exploited Vulnerabilities catalog. This package would have [DESCRIBE WHAT IT DOES — e.g. harvested credentials, enabled RCE]. It never touched the network."

**Expected output:** Install fails with a Curation block message showing the policy that triggered.

---

## Step 3 — CI build and Frogbot fix PR

**What to do:** Open the GitHub repo and point to the Frogbot PR that was auto-created.

**What to say:**
> "When this code reaches CI, Frogbot automatically scanned the pull request, found the same CVE, and created a fix PR for me. The developer never needs to leave GitHub. Here's the fix: upgrade [PACKAGE] from [VULNERABLE_VERSION] to [FIXED_VERSION]. One click to merge."

**Expected output:** A Frogbot PR comment showing CVE findings and a linked fix PR.

---

## Step 4 — Policy gate blocks promotion

**What to do:** Run `./demo.sh` or show the AppTrust Stages Board in the UI.

**What to say:**
> "This artifact has a CVSS [SCORE] finding. Our stage policy says: anything above 7.0 can't promote to stage. The gate blocks it. This is the enforcement mechanism — it's not advisory, it's a hard stop."

**Expected output:** Promotion fails with a Xray policy violation message.

---

## Step 5 — Clean version promotes

**What to do:** Switch to the fixed package version and re-run.

**What to say:**
> "Here's the same service with the dependency upgraded to [FIXED_VERSION]. Scan is clean. Policy gate passes. The artifact promotes to stage, then to prod. Full audit trail in AppTrust."

**Expected output:** Promotion succeeds; AppTrust Stages Board updates.

---

## Talking points

- **Shift left:** "We found this at IDE time, not in production. That's the JFrog shift-left story."
- **Curation:** "Malicious packages never reached a developer machine or a build server."
- **Frogbot:** "The developer's workflow is unchanged — they stay in GitHub."
- **Policy gates:** "Security is enforced, not just reported."
- **AppTrust:** "Full chain of custody — SBOM, scan evidence, build info, signatures — linked to every version in every stage."

---

## Fallback (if IDE or MCP fails)

```bash
cd traditional/REPLACE_PACKAGE_TYPE/sample-app
jf audit
```

This always works and shows the same findings.
