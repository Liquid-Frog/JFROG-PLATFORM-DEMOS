# Demo Script — PyPI

**Time:** ~10 minutes
**Mode:** Plugin (VS Code / IntelliJ) → CLI → AppTrust Stages Board
**Product coverage:** Xray · CISA KEV integration · JAS exploit maturity · AppTrust promotion
**Key CVEs:** CVE-2024-47874 (Starlette/FastAPI DoS, CVSS 8.7) · CVE-2025-3248 (Langflow RCE, CVSS 9.8, **CISA KEV**)

---

## Before you start

```bash
./setup/validate.sh                # verify instance is connected
./setup/prep.sh --service booking  # seed vulnerable PyPI packages
cd traditional/pypi
./demo.sh --reset                  # clean demo state
```

Open `traditional/pypi/sample-app/` in VS Code with the JFrog extension installed.

---

## Step 1 — Developer discovers CVEs at IDE time

**What to do:** Open `traditional/pypi/sample-app/requirements.txt` in VS Code.

**What to say:**
> "I've opened this FastAPI project. The JFrog extension immediately highlights
> two issues. First: starlette 0.36.3 — CVE-2024-47874, CVSS 8.7, a Denial of
> Service in the multipart upload handler. FastAPI uses starlette as its ASGI layer,
> so every FastAPI endpoint that accepts file uploads is exposed.
>
> Second — and this is the one I want to show you in detail — langflow 1.1.4.
> CVE-2025-3248, CVSS 9.8 Critical. This CVE is on the CISA Known Exploited
> Vulnerabilities catalog. That means the US government has confirmed this is
> being actively exploited in the wild right now. JFrog Xray pulls from the CISA
> KEV feed in real time. I didn't have to subscribe to a mailing list or run a
> separate tool. It's right here in the IDE."

**Expected output:** Red annotations on `starlette==0.36.3` and `langflow==1.1.4`
in requirements.txt. The langflow annotation should show the CISA KEV tag.

**MCP variant:**
> Type: *"Is CVE-2025-3248 exploitable in this project?"*
> Expected: JFrog MCP confirms the CVE, notes CISA KEV status, identifies the
> attack path via the `/recommend-carrier` endpoint that calls into Langflow.

---

## Step 2 — Publish vulnerable packages via JFrog PyPI

**What to do:** Run `./demo.sh` (or manually):

```bash
cd traditional/pypi/sample-app
jf pipc \
  --repo-resolve="${JFROG_REPO_PREFIX}-pypi-dev" \
  --repo-deploy="${JFROG_REPO_PREFIX}-pypi-dev" \
  --server-id-resolve=swiftship \
  --server-id-deploy=swiftship

# Install vulnerable packages via JFrog (caches them in Artifactory for Xray)
pip install starlette==0.36.3 langflow==1.1.4 \
  --index-url "${JFROG_URL}/artifactory/api/pypi/${JFROG_REPO_PREFIX}-pypi-dev/simple" \
  --no-deps
```

**What to say:**
> "When the build pipeline runs pip install, it resolves packages through JFrog's
> PyPI repository. Starlette 0.36.3 and langflow 1.1.4 are pulled down and cached
> in Artifactory. The moment they land in the repository, Xray begins indexing them.
> The developer's machine never interacts directly with PyPI — everything goes through
> JFrog, so JFrog has full visibility into every package that entered the supply chain."

---

## Step 3 — Xray flags CVE-2024-47874 (FastAPI/Starlette DoS)

**What to do:** Run `jf audit --pip` or show the Xray Violations view.

```bash
jf audit --pip --format=table
```

**What to say:**
> "CVE-2024-47874. Starlette 0.36.3. CVSS 8.7. The vulnerability is in how starlette
> reads multipart form data. An attacker sends a crafted multipart request with no
> Content-Length header. Starlette keeps reading. The server runs out of memory and
> crashes.
>
> Any FastAPI endpoint that accepts `UploadFile` — think: file upload, CSV import,
> image processing — is vulnerable. This booking service accepts shipping documents.
> That's a public-facing file upload endpoint. This is a real, exploitable path."

**Demonstrate in main.py:** Point to the `upload_document` endpoint and the
`await file.read()` line. There is no size limit because starlette 0.36.3 doesn't
enforce one. The VULN-SEED comment in the code explains exactly what's vulnerable.

**Expected output:**
```
┌─────────────────┬────────────┬──────────────────────────────────────┐
│ CVE             │ CVSS Score │ Package                              │
├─────────────────┼────────────┼──────────────────────────────────────┤
│ CVE-2024-47874  │ 8.7        │ starlette:0.36.3                    │
│ CVE-2025-3248   │ 9.8        │ langflow:1.1.4  ⚠️ CISA KEV         │
└─────────────────┴────────────┴──────────────────────────────────────┘
```

---

## Step 4 — CVE-2025-3248 (Langflow RCE) — CISA KEV — Stage gate BLOCKED

**What to do:** Attempt to promote to Stage. Show the Xray violation detail for CVE-2025-3248.

```bash
# Try to promote to Stage — expect a hard block
jf apptrust version-promote swiftship-booking-service 1.0.0 STAGE \
  --sync=true \
  --server-id=swiftship
```

In the Xray UI, click into the CVE-2025-3248 finding and show:
- CISA KEV indicator
- Exploit maturity: "Proof-of-Concept"
- EPSS score (likely high — CISA KEV entries have high EPSS)
- Affected endpoint: `/api/v1/run` in langflow (no authentication required)

**What to say:**
> "This is the finding I want to spend a moment on. CVE-2025-3248 in langflow 1.1.4.
> Unauthenticated Remote Code Execution. CVSS 9.8. But more importantly: it's on the
> CISA KEV catalog. That means the Cybersecurity and Infrastructure Security Agency —
> the US federal agency responsible for civilian government cybersecurity — has
> confirmed this vulnerability is being actively exploited in real attacks right now.
>
> Look at the exploit maturity indicator in Xray. It says 'Proof-of-Concept'. That
> means working exploit code is publicly available. Combined with the CISA KEV status,
> this is as high-urgency as a finding gets.
>
> Our Stage gate fires. The booking service cannot move to customers. The policy is
> clear: CVSS >= 7.0 blocks Stage promotion. This is how policy-as-code prevents a
> CISA KEV vulnerability from reaching production."

**Expected output:**
```
Promotion BLOCKED: CVE-2025-3248 (CVSS 9.8, CISA KEV) violates the lifecycle policy
standard: min_cvss_threshold = 7.0
Policy: demo-stage-policy
Action: block_release_bundle_promotion = true
```

**CISA KEV talking point:**
> "US Federal agencies are required by BOD 22-01 to patch CISA KEV entries within
> specific timeframes — sometimes as few as two weeks. If your company does business
> with the federal government, or if you follow NIST CSF, CISA KEV is a mandatory
> signal. JFrog integrates that signal directly into your development workflow."

---

## Step 5 — Fixed versions pass the Stage gate

**What to do:** Update `requirements.txt` to fixed versions:

```
starlette==0.40.0
langflow==1.3.0
```

Then re-audit and re-promote:

```bash
pip install starlette==0.40.0 langflow==1.3.0 --no-deps
jf audit --pip --format=table      # should be clean
jf apptrust version-promote swiftship-booking-service 1.0.1 STAGE --sync=true
```

**What to say:**
> "Two version bumps in requirements.txt — starlette to 0.40.0, langflow to 1.3.0.
> Xray re-scans and comes back clean. No findings above our 7.0 threshold.
>
> The Stage gate passes. The booking service is promoted. Version 1.0.1 is in
> Stage with a SBOM attached, the scan evidence signed, and the full audit trail —
> including the CISA KEV block on 1.0.0 — permanently recorded in AppTrust."

**Expected output:** Clean audit. Stage promotion succeeds.

---

## Talking points

- **CISA KEV real-time integration:** "Most companies learn about CISA KEV entries from email newsletters or Slack alerts — days after publication. JFrog pulls the CISA KEV feed continuously. Your Xray findings update in real time."
- **Exploit maturity vs CVSS:** "CVSS tells you theoretical severity. Exploit maturity tells you actual risk. A CVSS 9.8 with a Proof-of-Concept exploit and a CISA KEV tag is not the same as a CVSS 9.8 with no known exploit. JFrog shows you both signals."
- **FastAPI ubiquity:** "FastAPI is the fastest-growing Python web framework. Starlette underlies almost every modern Python microservice. CVE-2024-47874 is not a niche finding."
- **The gate vs advisory scanning:** "A vulnerability scanner tells you 'this is bad'. JFrog's lifecycle policy *stops the artifact from shipping* until it's fixed. That's the difference between a compliance checkbox and actual security."

---

## Frogbot talking point

> "When the engineer's PR added langflow 1.1.4, Frogbot scanned the pull request
> and posted a comment: 'CVE-2025-3248 (CVSS 9.8, CISA KEV) detected in langflow 1.1.4.
> Fix available: upgrade to 1.3.0'. It also opened a fix PR automatically.
> The engineer can review and merge without ever leaving GitHub."

---

## Fallback (if pip install / virtual environment fails)

```bash
cd traditional/pypi/sample-app
jf audit
```

`jf audit` reads `requirements.txt` directly without installing packages — shows
the same CVE findings. This always works regardless of the Python environment state.
