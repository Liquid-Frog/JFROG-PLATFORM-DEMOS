# JFrog Platform Demos

Reusable demo material for JFrog Solution Engineers. Covers the full JFrog platform from developer IDE to runtime — across every supported package type including AI/ML and agentic repositories.

## The demo app: SwiftShip

SwiftShip is a fictional e-commerce + logistics platform built as 8 polyglot microservices. Each service is a separate [AppTrust](https://docs.jfrog.com/governance/docs/jfrog-apptrust) Application with its own version lifecycle, security posture, and promotion path.

| Service | Language | AppTrust policy | Key demo CVEs |
|---|---|---|---|
| auth-service | Java / Maven | Strict (blocks CVSS ≥ 7) | CVE-2025-41234 (Spring RCE, CVSS 9.8), CVE-2025-41248 (Spring Security bypass, CVSS 9.1) |
| storefront-ui | Node.js / npm | Standard | CVE-2024-21538 (cross-spawn ReDoS), CVE-2025-10894 (Shai-Hulud supply chain) |
| booking-service | Python / PyPI | Standard | CVE-2024-47874 (FastAPI DoS), CVE-2025-3248 (Langflow RCE, CISA KEV) |
| payments-service | .NET / NuGet | Strictest (blocks any critical + license) | CVE-2024-21907 (Newtonsoft DoS), AGPL-3.0 license violation |
| logistics-service | Go modules | Standard | CVE-2025-22869 (golang.org/x/crypto), CVE-2025-22871 (net/http smuggling) |
| recommendation-engine | Python + HuggingFace | ML-specific | CVE-2025-3248, unapproved HF model blocked by Curation |
| ai-assistant | Python + MCP | AI-specific | Unapproved agent plugin blocked by Agent Plugins repo |
| infra / deploy | Helm + OCI | IaC | Root container + hardcoded secret caught by JAS |

## Quick start

```bash
# 1. Clone and configure
git clone https://github.com/YOUR-ORG/jfrog-platform-demos
cd jfrog-platform-demos
cp .env.example .env
# edit .env with your JFrog instance URL and token

# 2. Validate your environment
./setup/validate.sh

# 3. Bootstrap your JFrog instance (creates repos, policies, watches)
./setup/bootstrap.sh

# 4. Seed SwiftShip with vulnerabilities (night-before step)
./setup/prep.sh

# 5. Open e2e/swiftship in your IDE and start demoing
```

## Repository structure

```
jfrog-platform-demos/
├── setup/                    # bootstrap, validate, prep, reset scripts
├── e2e/                      # end-to-end SwiftShip demo (all products)
│   ├── swiftship/            # the 8 microservices
│   └── apptrust/             # AppTrust config-as-code
├── traditional/              # focused demos per package type
│   ├── _template/            # copy this to add a new package demo
│   ├── maven/  npm/  pypi/   docker/  go/  nuget/  helm/  gradle/
│   └── cocoapods/  conan/
├── ai-ml/                    # AI/ML and agentic package demos
│   ├── huggingface/          machine-learning/  nvidia-nim/  oci/
│   ├── mcp-registry/         skills/  agent-plugins/  ai-editor-extensions/
├── product-focus/            # focused demos per JFrog product
│   ├── xray/  curation/  jas/  promotion/  runtime/
└── .github/workflows/        # CI matrix, Frogbot, nightly reset
```

## Demo modes

**Plugin mode** (VS Code / IntelliJ): Open `e2e/swiftship/auth-service` in your IDE. The JFrog extension auto-connects to your sandbox instance via `.vscode/settings.json` and highlights CVEs inline.

**MCP mode** (Cursor / Claude Code / Codex): The `.cursor/mcp.json` and `.claude/settings.json` files are pre-configured. Ask your AI agent: *"What CVEs are critical in this project?"* or *"Is CVE-2025-41234 reachable in this codebase?"*

**CLI mode** (universal fallback): `jf audit` in any service directory.

## Prerequisites

- JFrog CLI v2+ (`jf --version`)
- JFrog Cloud instance with Xray, Curation, and JAS enabled
- AppTrust enabled on your instance
- GitHub account with Frogbot permissions
- For MCP mode: JFrog MCP Server enabled ([docs](https://docs.jfrog.com/integrations/docs/enable-the-jfrog-mcp-server))

## Shared instance setup

If multiple SolEng engineers share one JFrog instance, set `JFROG_PROJECT_KEY=se-yourname` in `.env`. The bootstrap script will namespace all repos and policies under a JFrog Project so you don't collide.

## Adding a new package demo

```bash
cp -r traditional/_template traditional/NEW-PACKAGE
# edit traditional/NEW-PACKAGE/README.md, demo.sh, sample-app/
```

## Links

- [JFrog AppTrust docs](https://docs.jfrog.com/governance/docs/jfrog-apptrust)
- [JFrog MCP Server](https://docs.jfrog.com/integrations/docs/jfrog-mcp-server)
- [JFrog Skills](https://github.com/jfrog/jfrog-skills)
- [Frogbot](https://github.com/jfrog/frogbot)
