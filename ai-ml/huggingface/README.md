# JFrog × HuggingFace — Private Model Registry with Governance

## Why this matters

The public HuggingFace Hub hosts over 900,000 models. Any developer on your team
can `huggingface-cli download` any of them — no approval, no audit trail, no security
scan. That is the same risk posture your organization had with public npm in 2015.

JFrog closes that gap for AI/ML:

| Risk | Without JFrog | With JFrog |
|---|---|---|
| Unapproved model orgs | Any developer can pull any model | Curation blocks unverified HF orgs before download |
| Malicious weights | Pickle files can embed arbitrary code | Xray scans `.pkl`, `.bin`, `.safetensors` for embedded threats |
| No license compliance | GPL/non-commercial models used in production | Xray license policy blocks restricted licenses |
| No audit trail | Unknown who pulled what model when | Every pull, version, and artifact logged in Artifactory |
| Model drift | Developers use different model versions in dev/prod | Virtual repos pin approved model versions per environment |
| No SBOM | Zero visibility into model provenance | Xray generates model SBOM with training data lineage (where available) |

**JFrog is the only binary management platform with native HuggingFace repository
support, Curation for model governance, and Xray scanning of model weights.**

---

## How it works

```
Developer / CI pipeline
        │
        │  HF_ENDPOINT=https://<instance>.jfrog.io/artifactory/api/huggingface/<virtual-repo>
        ▼
┌─────────────────────────────────────────────────────────────────┐
│              JFrog Artifactory                                    │
│                                                                   │
│  ┌─────────────────────────┐   ┌──────────────────────────────┐  │
│  │  Virtual HF Repo        │   │  Curation                    │  │
│  │  (unified access point) │──▶│  - Block unverified orgs     │  │
│  └──────────┬──────────────┘   │  - Block CVSS >= 7 models    │  │
│             │                  │  - Block non-commercial lic   │  │
│    ┌────────┼────────┐         └──────────────────────────────┘  │
│    ▼        ▼        ▼                                            │
│  Local    Remote   Remote       ┌──────────────────────────────┐  │
│  (private  (hf.co  (private     │  Xray                        │  │
│   models)  proxy)  orgs)        │  - Scan .pkl / .bin / .safet │  │
│                                 │  - License policy             │  │
│                                 │  - SBOM generation            │  │
│                                 └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
  Model cached in Artifactory — immutable, scanned, audited
```

---

## Repository types

| Repo type | Artifactory packageType | Purpose |
|---|---|---|
| Local | `huggingfaceml` | Private/fine-tuned models your org produces |
| Remote | `huggingfaceml` → `https://huggingface.co` | Curation-filtered proxy to the public Hub |
| Virtual | `huggingfaceml` | Unified endpoint for clients (`HF_ENDPOINT`) |

---

## Curation policy examples

Curation rules that make sense for enterprise model governance:

```yaml
# Block unapproved community organizations
- rule: org_not_in_allowlist
  action: block
  allowlist_orgs:
    - google
    - meta-llama
    - microsoft
    - sentence-transformers
    - openai

# Block models with non-commercial licenses
- rule: license_restricted
  action: block
  blocked_licenses:
    - llama2-community         # Meta Llama 2 community (non-commercial)
    - cc-by-nc-4.0             # Non-commercial Creative Commons
    - other                    # Unknown / missing license

# Block models with known security findings
- rule: xray_violation
  action: block
  min_severity: high
```

---

## Quick start

```bash
# 1. Configure the HuggingFace virtual repo as your HF endpoint
export HF_ENDPOINT="https://<instance>.jfrog.io/artifactory/api/huggingface/demo-huggingface-virtual"
export HF_TOKEN="<your-jfrog-access-token>"

# 2. Use the standard HuggingFace CLI — JFrog is transparent
huggingface-cli download sentence-transformers/all-MiniLM-L6-v2 config.json

# 3. Or use the Python SDK
python3 -c "
from huggingface_hub import hf_hub_download
hf_hub_download('sentence-transformers/all-MiniLM-L6-v2', 'config.json')
"

# 4. Run the live demo
./demo.sh
```

---

## JFrog MCP integration

When the JFrog MCP Server is enabled, AI agents can query model governance status:

```
User: "Is the sentence-transformers/all-MiniLM-L6-v2 model approved for production use?"
Agent: [calls curation_packages_get_status]
→ "Model is APPROVED. License: Apache-2.0. No security findings. Cached in demo-huggingface-local."
```

---

## Links

- [JFrog HuggingFace Repository docs](https://docs.jfrog.com/artifactory/docs/huggingface-ml-repositories)
- [JFrog Curation for AI/ML](https://docs.jfrog.com/curation/docs/curation-overview)
- [HuggingFace Hub Python SDK](https://huggingface.co/docs/huggingface_hub)
- [JFrog Xray for ML models](https://docs.jfrog.com/xray/docs/xray-overview)
