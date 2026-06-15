# ══════════════════════════════════════════════════════════════════════════════
# standard.rego — Lifecycle policy for standard-profile services
#
# Applies to: policy_profile = "standard"
#             services: storefront-ui, booking-service, logistics-service
# Evaluated at: every promotion gate (DEV→STAGE and STAGE→PROD)
#
# Rules summary:
#   BLOCK  — any CVE with CVSS >= 9.0 on promotion to PROD (Critical)
#   WARN   — any CVE with CVSS >= 7.0 (High) at any stage
#   WARN   — any Critical CVE at non-PROD stages (pre-emptive alert)
#   ALLOW  — all other promotions
#
# The distinction between BLOCK and WARN reflects the graduated risk model:
#   - High findings (7.0–8.9) are tracked and must be remediated within the
#     next sprint, but they do not stop a release from shipping to staging.
#   - Critical findings (>= 9.0) are a hard stop for production: they could
#     represent an actively exploitable RCE or a CISA KEV entry.
#
# Input schema: same as payments-strict.rego
# ══════════════════════════════════════════════════════════════════════════════

package apptrust.lifecycle.standard

# ── Constants ────────────────────────────────────────────────────────────────

# Findings at or above this score BLOCK promotion to PROD.
block_threshold := 9.0

# Findings at or above this score WARN at all stages (do not block).
warn_threshold := 7.0

# ── Block rule: Critical CVE going to production ──────────────────────────────
#
# Only fires when target_stage is "PROD". This intentionally allows Critical
# findings to pass through Dev and Stage — they produce warnings there so
# the team is aware, but they do not block iteration speed.
#
# Demo scenario: booking-service contains CVE-2025-3248 (Langflow RCE, CVSS 9.8,
# CISA KEV). This rule fires when the engineer tries to promote it to PROD,
# pausing to explain why a CISA KEV finding is a hard block even without a
# specific organisation policy — the standard policy is the safety net.
deny[msg] {
    input.application.target_stage == "PROD"
    some i
    vuln := input.vulnerabilities[i]
    vuln.cvss_score >= block_threshold
    msg := sprintf(
        "BLOCKED [standard → PROD]: %v (CVSS %.1f, %v) in %v@%v must be " +
        "remediated before this version can be promoted to production. " +
        "Upgrade the affected package%v or raise a security waiver.",
        [
            vuln.cve_id,
            vuln.cvss_score,
            vuln.severity,
            vuln.package_name,
            vuln.package_version,
            fix_hint(vuln),
        ]
    )
}

# ── Helper: format a fix hint from available fixed versions ──────────────────
#
# Returns an empty string when no fix versions are known, otherwise formats
# a helpful upgrade suggestion. Used inside sprintf above.
fix_hint(vuln) := hint {
    count(vuln.fixed_versions) > 0
    hint := sprintf(" (upgrade to %v)", [vuln.fixed_versions])
} else := ""

# ── Warn rule 1: High-severity findings at any stage ─────────────────────────
#
# Warns on CVSS 7.0–8.9 at every stage (Dev, Stage, and Prod).
# At Prod this rule co-exists with the block rule above: a Critical finding
# both warns AND blocks, so the violation appears in the audit log with full
# detail regardless of the enforcement outcome.
#
# Demo scenario: storefront-ui contains CVE-2024-21538 (cross-spawn ReDoS,
# CVSS 7.3). This warns but does not block the Stage promotion, demonstrating
# to the audience that the team has visibility without being slowed down.
warn[msg] {
    some i
    vuln := input.vulnerabilities[i]
    vuln.cvss_score >= warn_threshold
    vuln.cvss_score < block_threshold
    msg := sprintf(
        "WARNING [standard]: %v (CVSS %.1f, High) found in %v@%v. " +
        "This finding does not block promotion but must be addressed before " +
        "the next release cycle. %v",
        [
            vuln.cve_id,
            vuln.cvss_score,
            vuln.package_name,
            vuln.package_version,
            remediation_advice(vuln),
        ]
    )
}

# ── Warn rule 2: Critical CVEs at non-production stages ──────────────────────
#
# When a Critical finding is present and the target stage is NOT PROD, emit
# a prominent warning so the team knows a prod-blocking issue is in flight.
# This gives engineers early visibility — they see the warning at Stage and
# can fix it before the prod promotion gate fires.
warn[msg] {
    input.application.target_stage != "PROD"
    some i
    vuln := input.vulnerabilities[i]
    vuln.cvss_score >= block_threshold
    msg := sprintf(
        "PRE-BLOCKING WARNING [standard]: %v (CVSS %.1f, Critical) in %v@%v " +
        "will BLOCK promotion to PROD if not resolved. %v",
        [
            vuln.cve_id,
            vuln.cvss_score,
            vuln.package_name,
            vuln.package_version,
            remediation_advice(vuln),
        ]
    )
}

# ── Helper: remediation advice ───────────────────────────────────────────────
#
# Returns a remediation string based on whether fixed versions are known.
remediation_advice(vuln) := advice {
    count(vuln.fixed_versions) > 0
    advice := sprintf(
        "Upgrade %v to %v to resolve this finding.",
        [vuln.package_name, vuln.fixed_versions]
    )
} else := advice {
    advice := sprintf(
        "No fixed version is currently available for %v. " +
        "Consider a waiver with justification or an alternative dependency.",
        [vuln.package_name]
    )
}

# ── Allow rule ────────────────────────────────────────────────────────────────
#
# Promotion is allowed when no deny rules matched.
# Warnings are recorded in the AppTrust audit log and posted to the owning
# team's notification channel, but they do not affect this allow decision.
allow {
    count(deny) == 0
}
