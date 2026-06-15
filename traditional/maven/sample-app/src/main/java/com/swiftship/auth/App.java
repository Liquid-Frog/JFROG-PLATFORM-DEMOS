package com.swiftship.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * SwiftShip Auth Service Demo — minimal Spring Boot app
 *
 * Intentionally uses vulnerable dependency versions for the JFrog Xray demo:
 *   spring-core 6.1.6        → CVE-2025-41234 (path traversal RCE, CVSS 9.8)
 *   spring-security-core 6.2.2 → CVE-2025-41248 (authorization bypass, CVSS 9.1)
 *
 * See pom.xml VULN-SEED comments and traditional/maven/demo.sh for the live demo.
 */
@SpringBootApplication
@RestController
@EnableMethodSecurity
public class App {

    // ── Health endpoint ──────────────────────────────────────────────
    // Used by demo.sh step 1 and Kubernetes liveness probe
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status",  "UP",
            "service", "auth-service-demo",
            "version", "1.0.0"
        ));
    }

    // ── Token verification endpoint ──────────────────────────────────
    // Demonstrates the auth surface that CVE-2025-41248 can bypass.
    // In 6.2.2, certain Authorization header formats can skip the @PreAuthorize check.
    @GetMapping("/api/auth/verify")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, Object>> verify(
            @RequestHeader(value = "Authorization", required = false) String token) {

        if (token == null || !token.startsWith("Bearer ")) {
            return ResponseEntity.status(401).body(Map.of(
                "valid",   false,
                "message", "No Bearer token provided"
            ));
        }

        // VULN-SEED (SCA): CVE-2025-41248 — in spring-security 6.2.2, a malformed
        // Authorization header can bypass @PreAuthorize and reach this code path
        // without proper authentication. Fix: upgrade to spring-security 6.3.4+
        return ResponseEntity.ok(Map.of(
            "valid",   true,
            "user",    "demo@swiftship.example",
            "service", "auth-service-demo",
            "note",    "Demo only — not a real JWT validator"
        ));
    }

    // ── Path traversal demo endpoint ─────────────────────────────────
    // Illustrates the attack surface for CVE-2025-41234.
    // In spring-core 6.1.6, specific URL patterns can traverse the webapp root.
    @GetMapping("/api/files/{filename}")
    public ResponseEntity<Map<String, String>> serveFile(@PathVariable String filename) {
        // VULN-SEED (SCA): CVE-2025-41234 — in spring-core 6.1.6, a crafted
        // {filename} value containing path traversal sequences (e.g. "../../etc/passwd")
        // can escape the intended directory. Fix: upgrade to spring-core 6.1.14+
        return ResponseEntity.ok(Map.of(
            "file",  filename,
            "note",  "Demo only — path traversal CVE-2025-41234 in spring-core 6.1.6",
            "vuln",  "Upgrade to spring-core 6.1.14+ to remediate"
        ));
    }

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }
}
