# JFrog MCP Registry — AI Agent Integration & MCP Server Governance

## Why this matters

The Model Context Protocol (MCP) is becoming the standard interface for AI coding
agents to interact with external tools and data sources. Every MCP server a developer
adds to Cursor or Claude Code is a piece of code running in their development
environment with access to their filesystem, terminal, and credentials.

JFrog addresses two distinct MCP challenges:

### Challenge 1 — The JFrog MCP Server (immediate value)

JFrog publishes an official MCP Server that exposes the entire JFrog Platform to
AI coding agents. Developers can ask their AI assistant:

- *"What CVEs are in my auth-service dependencies?"* — Xray responds with live data
- *"Is this package blocked by Curation today?"* — real-time policy status
- *"Promote auth-service 1.0.1 to Stage"* — AppTrust lifecycle automation
- *"Generate an SBOM for my latest build"* — Evidence Service integration

This is JFrog's shift-left story applied to AI — instead of running `jf audit` and
reading a table, the developer gets a natural-language conversation with live JFrog data.

### Challenge 2 — MCP Server Package Governance (differentiated)

AI teams build custom MCP servers (data connectors, internal tool wrappers, API
bridges). Without governance, these servers are:
- Shared as GitHub repos or Slack messages — no versioning, no signing
- Not scanned for embedded secrets or malicious code
- Unknown which version each team is running

**JFrog MCP Registry** stores custom MCP server packages in Artifactory:
versioned, signed, Xray-scanned, and distributable via the standard JFrog
distribution pipeline.

| Capability | Public MCP servers | JFrog MCP Registry |
|---|---|---|
| Versioning | Git tags, informal | Semantic versioning in Artifactory |
| Security scanning | None | Xray scans every package version |
| Signed packages | None | Signed with JFrog signing keys |
| Audit trail | None | Who published/installed what version, when |
| Distribution | Share a URL | Release Bundles, edge distribution |
| Curation | None | Block servers with CVEs or policy violations |

---

## MCP tool inventory

The JFrog MCP Server exposes these tool categories. Each maps to a JFrog product:

| Category | Representative tools | JFrog product |
|---|---|---|
| Vulnerability queries | `catalog_vulnerabilities_get`, `curation_packages_get_status`, `artifactory_artifacts_get_summary` | Xray + Curation |
| Repository management | `artifactory_repositories_create`, `artifactory_repositories_list` | Artifactory |
| Build information | `artifactory_builds_list_builds`, `artifactory_builds_get_info` | Artifactory |
| AppTrust lifecycle | `apptrust_promote_version`, `apptrust_list_applications`, `apptrust_get_lifecycle_overview` | AppTrust |
| Evidence / SBOM | `evidence_records_search`, `evidence_records_get_by_subject` | Evidence Service |
| Distribution | `distribution_release_bundles_distribute`, `distribution_trackers_list` | Distribution |
| Access management | `access_tokens_create`, `access_projects_list_projects` | Access |

---

## Enabling the JFrog MCP Server

1. Log in as Platform Admin → navigate to **Platform → Integrations**
2. Click **JFrog MCP Server → Set Up**
3. Accept the Beta Agreement
4. Copy the MCP Server URL: `https://<your-instance>.jfrog.io/mcp`

The MCP Server URL is then configured in each AI agent client (see samples below).

---

## Client configuration samples

### Cursor — `.cursor/mcp.json`

```json
{
  "mcpServers": {
    "jfrog": {
      "url": "https://<your-instance>.jfrog.io/mcp",
      "headers": {
        "Authorization": "Bearer <your-access-token>"
      }
    }
  }
}
```

### Claude Code — `.claude/settings.json`

```json
{
  "mcpServers": {
    "jfrog": {
      "type": "sse",
      "url": "https://<your-instance>.jfrog.io/mcp",
      "headers": {
        "Authorization": "Bearer <your-access-token>"
      }
    }
  }
}
```

Both files in this directory use `${JFROG_MCP_URL}` and `${JFROG_TOKEN}` as
environment variable references (expanded at runtime by the agent harness).

---

## MCP Registry package format

Custom MCP server packages are stored as generic archives in an Artifactory local repo.

Recommended structure:
```
{repo}/{mcp-server-name}/{version}/{mcp-server-name}-{version}.tar.gz
```

Each package should include:
- `package.json` / `pyproject.toml` (server manifest)
- Server source or compiled binary
- `mcp-server.json` (JFrog metadata: capabilities, transport, tool list)
- Signing certificate reference

---

## Quick start

```bash
# Run the live demo
./demo.sh

# Or run non-interactively (CI/CD)
./demo.sh --ci
```

---

## Links

- [Enable the JFrog MCP Server](https://docs.jfrog.com/integrations/docs/enable-the-jfrog-mcp-server)
- [JFrog MCP Server Tools reference](https://docs.jfrog.com/integrations/docs/jfrog-mcp-server-tools)
- [MCP Protocol specification](https://modelcontextprotocol.io)
- [github.com/jfrog/jfrog-skills](https://github.com/jfrog/jfrog-skills)
