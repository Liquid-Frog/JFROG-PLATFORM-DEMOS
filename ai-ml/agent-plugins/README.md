# JFrog Agent Plugins — Enterprise Governance for AI Coding Agent Extensions

## Why this matters

AI coding agents (Claude Code, Cursor, GitHub Copilot, Codex) are extensible through
plugins. These plugins run locally, have access to the developer's filesystem and
terminal, and can make outbound network requests. In short: they are code executing
inside your software development environment.

The public plugin marketplaces for these agents have **no enterprise governance**:

- Any plugin can be installed by any developer with no approval workflow
- Plugins are not scanned for malicious code or embedded credentials
- There is no audit trail of who installed which plugin version
- Supply-chain attacks via compromised plugins are already documented in the wild

**JFrog Agent Plugins repositories close this gap — the same way JFrog closed it
for npm, PyPI, and Maven a decade ago.**

### The analogy your customers already understand

| Then (2015) | Now (2024–2025) |
|---|---|
| Developers pulled npm packages from registry.npmjs.org directly | Developers install agent plugins from public marketplaces directly |
| No Curation — malicious packages downloaded to CI servers | No governance — malicious plugins run in developer environments |
| JFrog: proxy npm through Artifactory, Curation blocks bad packages | JFrog: proxy agent marketplaces through Artifactory, block unapproved plugins |
| Full audit trail: who downloaded what npm package, when | Full audit trail: who installed what agent plugin, when |

---

## How it works

```
Developer installs a plugin in Claude Code / Cursor / Codex
        │
        │  Marketplace URL = https://<instance>.jfrog.io/artifactory/api/agentplugins/<repo>/
        ▼
┌─────────────────────────────────────────────────────────────────┐
│              JFrog Artifactory                                    │
│                                                                   │
│  ┌─────────────────────────┐                                     │
│  │  Agent Plugins Repo     │──▶ Curation checks:                 │
│  │  (packageType:          │    - Is this plugin on the          │
│  │   agentplugins)         │      approved list?                 │
│  │                         │    - Any CVEs (Xray)?               │
│  │  claude-marketplace.json│    - Valid signing signature?       │
│  │  cursor-marketplace.json│                                     │
│  │  codex-marketplace.json │    Blocked? → 403, audit logged     │
│  │                         │    Approved? → plugin served        │
│  └─────────────────────────┘                                     │
│                                                                   │
│  Audit log: {user} installed {plugin}@{version} at {timestamp}  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository details

**Artifactory package type:** `agentplugins`

**Marketplace API endpoints (served by Artifactory):**
```
# Claude Code
GET /artifactory/api/agentplugins/{repo}/claude-marketplace.json

# Cursor
GET /artifactory/api/agentplugins/{repo}/cursor-marketplace.json

# Codex
GET /artifactory/api/agentplugins/{repo}/codex-marketplace.json
```

**Plugin storage format:**
```
{repo}/{plugin-name}/{version}/{plugin-name}-{version}.zip
```

---

## Configuring agents to use JFrog

### Claude Code

Add to `.claude/settings.json` or configure via the `jf agent plugins` CLI:

```json
{
  "pluginRegistry": "https://<user>:<token>@<instance>.jfrog.io/artifactory/api/agentplugins/<repo>"
}
```

### Cursor

Point Cursor's plugin source to the JFrog Agent Plugins repo:

```json
{
  "cursor.pluginSource": "https://<instance>.jfrog.io/artifactory/api/agentplugins/<repo>/cursor-marketplace.json"
}
```

---

## CLI commands

```bash
# Publish a plugin to the internal registry
jf agent plugins publish ./my-plugin-folder \
  --repo demo-agent-plugins-local \
  --version 1.2.0 \
  --signing-key ./signing-key.pem \
  --build-name my-plugin-build \
  --build-number 42

# Install an approved plugin
jf agent plugins install jfrog-security \
  --repo demo-agent-plugins-local \
  --harness claude \
  --version 2.1.0

# Install flags
#   --version   : pin to a specific version (omit for latest)
#   --global    : install globally (not per-project)
#   --project-dir : install into a specific project directory
#   --harness   : claude | cursor | codex
```

---

## Links

- [JFrog Agent Plugins Repositories](https://docs.jfrog.com/artifactory/docs/agent-plugins-repositories)
- [JFrog Curation](https://docs.jfrog.com/curation/docs/curation-overview)
- [JFrog Xray](https://docs.jfrog.com/xray/docs/xray-overview)
- [Claude Code plugin system](https://claude.ai/code)
- [Cursor extension system](https://docs.cursor.com)
