module github.com/swiftship/logistics-service

// VULN-SEED (CVE): go 1.23.0 stdlib — CVE-2025-22871 (net/http request
// smuggling, CVSS 7.5) and CVE-2025-22874 (crypto/x509 policy bypass,
// CVSS 7.5) — Fix: upgrade to go 1.24.4+
go 1.23.0

require (
	// VULN-SEED (CVE): golang.org/x/crypto v0.14.0 — CVE-2025-22869
	// (SSH DoS via slow key exchange, CVSS 7.5) — Fix: upgrade to v0.35.0+
	golang.org/x/crypto v0.14.0

	// VULN-SEED (CVE): golang.org/x/net v0.17.0 — CVE-2023-44487
	// (HTTP/2 rapid reset attack, CVSS 7.5) — Fix: upgrade to v0.38.0+
	golang.org/x/net v0.17.0
)
