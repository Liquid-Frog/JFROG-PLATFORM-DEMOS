# ══════════════════════════════════════════════════════════════════════════════
# payments-strict.rego — Lifecycle policy for swiftship-payments-service
#
# Applies to: policy_profile = "strict" or "payments-strict" (via labels)
# Evaluated at: every promotion gate (DEV→STAGE and STAGE→PROD)
#
# Rules summary:
#   BLOCK  — any CVE with CVSS >= 7.0 (unless an approved waiver exists)
#   BLOCK  — any dependency with AGPL or GPL license (waivers NOT accepted)
#   ALLOW  — promotion proceeds when no deny rules fire
#
# Input schema (provided by AppTrust at evaluation time):
# {
#   "application": {
#     "app_key":      string,   # e.g. "swiftship-payments-service"
#     "version":      string,   # e.g. "1.2.0"
#     "source_stage": string,   # e.g. "DEV"
#     "target_stage": string    # e.g. "STAGE"
#   },
#   "vulnerabilities": [
#     {
#       "cve_id":          string,  # e.g. "CVE-2024-21907"
#       "cvss_score":      number,  # e.g. 7.5
#       "severity":        string,  # "low"|"medium"|"high"|"critical"
#       "package_name":    string,
#       "package_version": string,
#       "fixed_versions":  [string]
#     }
#   ],
#   "licenses": [
#     {
#       "package_name":    string,
#       "package_version": string,
#       "license":         string   # SPDX identifier, e.g. "AGPL-3.0"
#     }
#   ],
#   "approved_waivers": [
#     {
#       "cve_id":          string,
#       "approved_by":     string,
#       "justification":   string,
#       "expiry_date":     string   # ISO-8601, optional
#     }
#   ]
# }
# ══════════════════════════════════════════════════════════════════════════════

package apptrust.lifecycle.payments_strict

# ── Constants ────────────────────────────────────────────────────────────────

# The minimum CVSS score that triggers a block for this policy.
cvss_threshold := 7.0

# Licenses that are prohibited in a commercial payments component (PCI-DSS scope).
# These cannot be waived — a dependency must be replaced, not waived.
prohibited_licenses := {
    "AGPL-3.0",
    "AGPL-3.0-only",
    "AGPL-3.0-or-later",
    "GPL-2.0",
    "GPL-2.0-only",
    "GPL-2.0-or-later",
    "GPL-3.0",
    "GPL-3.0-only",
    "GPL-3.0-or-later",
}

# ── Helper: waiver check ─────────────────────────────────────────────────────

# is_waived(cve_id) is true when an approved_waiver entry exists for the CVE.
# Waivers without an expiry_date are treated as permanent (open-ended).
# Waivers with an expiry_date are accepted without time comparison here —
# bootstrap.sh prunes expired waivers before policy evaluation.
# Note: waivers are never valid for license violations (see deny rules below).
is_waived(cve_id) {
    some i
    waiver := input.approved_waivers[i]
    waiver.cve_id == cve_id
}

# ── Block rule 1: CVE above CVSS threshold ───────────────────────────────────
#
# Blocks promotion when a vulnerability's CVSS score meets or exceeds the
# threshold AND no approved waiver exists for that specific CVE.
#
# Demo scenario: CVE-2024-21907 (Newtonsoft.Json 12.0.3, CVSS 7.5) fires this
# rule. The engineer submits a waiver ("can't migrate this sprint") which is
# approved by the security-team. On re-evaluation, is_waived fires and this
# deny rule no longer matches — promotion succeeds.
deny[msg] {
    some i
    vuln := input.vulnerabilities[i]
    vuln.cvss_score >= cvss_threshold
    not is_waived(vuln.cve_id)
    msg := sprintf(
        "BLOCKED [payments-strict]: %v (CVSS %.1f, %v) in %v@%v exceeds the " +
        "%.1f threshold for payments services. Upgrade to a fixed version %v " +
        "or request a security-team waiver with justification and expiry date.",
        [
            vuln.cve_id,
            vuln.cvss_score,
            vuln.severity,
            vuln.package_name,
            vuln.package_version,
            cvss_threshold,
            vuln.fixed_versions,
        ]
    )
}

# ── Block rule 2: waived CVE audit trail ─────────────────────────────────────
#
# When a CVE is waived, emit a warn-level message so the waiver appears
# in the AppTrust audit log even though the promotion is not blocked.
# Implemented as a deny at warn severity (AppTrust distinguishes severity
# in the violation payload; "warn" violations do not block).
warn[msg] {
    some i
    vuln := input.vulnerabilities[i]
    vuln.cvss_score >= cvss_threshold
    is_waived(vuln.cve_id)
    msg := sprintf(
        "WAIVED [payments-strict]: %v (CVSS %.1f) has an approved waiver. " +
        "Promotion is permitted. Waiver must be reviewed before next release cycle.",
        [vuln.cve_id, vuln.cvss_score]
    )
}

# ── Block rule 3: prohibited open-source license ─────────────────────────────
#
# Blocks promotion when any dependency carries a copyleft license that is
# incompatible with commercial/PCI-DSS use. Unlike CVE waivers, license
# violations cannot be waived — the dependency MUST be replaced.
#
# Demo scenario: iTextSharp 5.5.13.3 carries AGPL-3.0. This block fires even
# after the CVE-2024-21907 waiver is approved, proving to the audience that
# two independent policy dimensions (security AND compliance) must both pass.
deny[msg] {
    some i
    lic := input.licenses[i]
    lic.license in prohibited_licenses
    msg := sprintf(
        "BLOCKED [payments-strict]: Package '%v@%v' uses %v, which is a " +
        "prohibited copyleft license in a PCI-DSS-scoped payments component. " +
        "Waivers are NOT accepted for license violations. " +
        "Replace this dependency with a permissively-licensed alternative or " +
        "obtain a commercial license from the vendor.",
        [lic.package_name, lic.package_version, lic.license]
    )
}

# ── Allow rule ────────────────────────────────────────────────────────────────
#
# Promotion is allowed when the deny set is empty.
# AppTrust evaluates this rule last — if it is false, the promotion is blocked
# and the deny messages are surfaced in the UI and posted to the owning team.
allow {
    count(deny) == 0
}
