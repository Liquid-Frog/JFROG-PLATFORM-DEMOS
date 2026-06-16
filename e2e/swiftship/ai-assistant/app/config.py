import os

# VULN-SEED (JAS-Secret): hardcoded OpenAI API key — JAS detects the sk-proj- prefix pattern — Fix: inject from environment variable OPENAI_API_KEY; never hardcode in source
OPENAI_API_KEY = "sk-proj-dEmO9xK2mNpQ7vR4wL8jH3cF6yT1sA0bE5nU2iO"  # noqa: S105

# JFrog MCP Server config — reads from environment (correctly done)
JFROG_MCP_URL = os.environ.get("JFROG_MCP_URL", "")
JFROG_TOKEN = os.environ.get("JFROG_TOKEN", "")

# VULN-SEED (Curation): references an unapproved external Cursor plugin registry — the Agent Plugins repo policy blocks installation of plugins not sourced from Artifactory — Fix: point CURSOR_PLUGIN_REGISTRY to the internal agent-plugins-local repo in Artifactory
CURSOR_PLUGIN_REGISTRY = "https://marketplace.cursor.sh/plugins"  # external — blocked by policy
# CURSOR_PLUGIN_REGISTRY = f"{os.environ.get('JFROG_URL')}/artifactory/agent-plugins-local"
