/**
 * SwiftShip Storefront Demo — minimal Express app
 *
 * Demonstrates npm supply-chain risk:
 *   - cross-spawn 7.0.3  → CVE-2024-21538 (ReDoS, CVSS 7.5)
 *   - @nx/devkit 19.5.0  → CVE-2025-10894 (Shai-Hulud supply-chain, blocked by Curation)
 *
 * Run: node index.js
 */
'use strict';

const express = require('express');
// VULN-SEED (CVE): cross-spawn 7.0.3 — CVE-2024-21538 (ReDoS in argument parsing, CVSS 7.5) — Fix: upgrade to cross-spawn 7.0.5
const spawn = require('cross-spawn');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health check — used by demo.sh and Kubernetes liveness probe
app.get('/health', (req, res) => {
  res.json({ status: 'UP', service: 'storefront-demo', version: '1.0.0' });
});

// Products endpoint — main storefront functionality
app.get('/api/products', (req, res) => {
  res.json([
    { id: 1, name: 'Express Shipping Box',  price: 9.99,  sku: 'BOX-001' },
    { id: 2, name: 'Overnight Envelope',    price: 14.99, sku: 'ENV-002' },
    { id: 3, name: 'Pallet Wrap Service',   price: 49.99, sku: 'PLT-003' },
  ]);
});

// Build-info endpoint — uses cross-spawn to show actual package usage
// This is intentionally invoking cross-spawn so Xray sees real library usage,
// not just a dependency declaration.
app.get('/api/build-info', (req, res) => {
  // cross-spawn 7.0.3 is called here — the ReDoS vector is in its argument parsing
  const nodeInfo = spawn.sync(process.execPath, ['--version'], { encoding: 'utf8' });
  res.json({
    node_version:   (nodeInfo.stdout || '').trim(),
    cross_spawn:    '7.0.3',
    vuln_note:      'CVE-2024-21538: ReDoS in cross-spawn argument handling. Fix: 7.0.5',
    demo_only:      true,
  });
});

app.listen(PORT, () => {
  console.log(`SwiftShip storefront-demo listening on :${PORT}`);
  console.log(`  GET /health       — liveness check`);
  console.log(`  GET /api/products — product catalogue`);
  console.log(`  GET /api/build-info — runtime info`);
});
