> **⚠️ BETA FEATURE** — JFrog Skills Repositories are currently in Beta.
> APIs, CLI commands, and behaviour may change before GA. Not recommended
> for production use without JFrog support guidance. See the
> [Beta disclaimer](https://docs.jfrog.com/artifactory/docs/skills-repositories).

---

# JFrog Skills Repositories — Enterprise-Grade AI Agent Skill Distribution

## Why this matters

AI coding agents (Claude Code, Cursor, Codex) can be extended with "skills" —
reusable capabilities that teach the agent how to interact with specific tools,
APIs, or internal systems. Examples:

- A **JFrog skill** that teaches an agent how to query Xray, create repos, and promote artifacts
- An **internal API skill** that gives agents access to your company's internal service catalogue
- A **security playbook skill** that teaches agents your incident response runbooks

Without governance, skills are shared as GitHub repos or copy-pasted into agent
config files — the same uncontrolled distribution problem that existed for npm
packages before enterprise binary management existed.

**JFrog Skills Repositories bring enterprise-grade distribution to the emerging
skills ecosystem:**

| Problem | Without JFrog | With JFrog Skills Repos |
|---|---|---|
| Discovery | "Ask Alice in Slack" | ClawHub discovery endpoint — agents find skills automatically |
| Versioning | `main` branch, hopes | Semantic versioning with `--version latest` resolution |
| Security | No scanning | Xray scans every published skill version |
| Audit | Unknown who uses what | Full install audit trail in Artifactory |
| Distribution | GitHub URL, breaks on change | Immutable versioned artifacts in Artifactory |
| Access control | Public GitHub | Repo-level permissions, project namespacing |

**JFrog is the first enterprise-ready skills registry with the ClawHub protocol.**

---

## The ClawHub Protocol

ClawHub is the open protocol for skills discovery and distribution. JFrog
Artifactory implements it natively.

```
Agent client (Claude Code / Cursor)
        │
        │  GET /.well-known/clawhub.json
        ▼
┌─────────────────────────────────────────────────────────────────┐
│  JFrog Artifactory Skills Repo                                   │
│                                                                   │
│  Discovery:  /.well-known/clawhub.json                          │
│  Skills API: /artifactory/api/skills/{repo}/api/v1/skills       │
│                                                                   │
│  Storage:  {slug}/{version}/{slug}-{version}.zip                 │
│  Metadata: SKILL.md YAML frontmatter → skill.* properties       │
│                                                                   │
│  Example: jfrog/2.1.0/jfrog-2.1.0.zip                          │
└─────────────────────────────────────────────────────────────────┘
```

### `SKILL.md` frontmatter format

Every skill package must include a `SKILL.md` at its root:

```markdown
---
name: JFrog Platform
slug: jfrog
version: 2.1.0
description: Interact with the JFrog Platform via the JFrog CLI and REST/GraphQL APIs.
author: JFrog
license: Apache-2.0
min_agent_version: "1.0"
tags:
  - artifactory
  - xray
  - security
  - devops
---

# JFrog Platform Skill

[Skill documentation...]
```

---

## Repository details

**Artifactory package type:** `skills`

**Required JFrog CLI version:** `v2.98.0+`

**Storage format:** `{slug}/{version}/{slug}-{version}.zip`

**Slug requirements:** lowercase letters, digits, and hyphens; must start with a
letter or digit (`^[a-z0-9][a-z0-9-]*$`)

---

## CLI commands

```bash
# Requires JFrog CLI v2.98.0+

# Publish a skill to Artifactory
jf skills publish ./my-skill-folder \
  --repo demo-skills-local \
  --version 1.0.0        # optional; defaults to SKILL.md version field

# Install a skill from Artifactory
jf skills install jfrog \
  --agent claude \
  --repo demo-skills-local \
  --version latest        # or pin to a specific version

# Install for other agents
jf skills install jfrog --agent cursor --repo demo-skills-local
```

---

## Official JFrog Skills

JFrog publishes and maintains official skills at:
**https://github.com/jfrog/jfrog-skills**

These are also distributed via the public JFrog Skills Registry and can be
mirrored into your private Artifactory instance for governance.

---

## Quick start

```bash
./demo.sh           # interactive
./demo.sh --ci      # CI/headless mode
./demo.sh --reset   # clean state
```

---

## Links

- [JFrog Skills Repositories (Beta)](https://docs.jfrog.com/artifactory/docs/skills-repositories)
- [github.com/jfrog/jfrog-skills](https://github.com/jfrog/jfrog-skills)
- [ClawHub Protocol](https://github.com/clawhub)
- [JFrog CLI Skills commands](https://docs.jfrog.com/integrations/docs/jfrog-cli-skills)
