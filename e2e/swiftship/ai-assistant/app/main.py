from fastapi import FastAPI
from pydantic import BaseModel

from app.config import JFROG_MCP_URL, JFROG_TOKEN, OPENAI_API_KEY

app = FastAPI(title="SwiftShip AI Assistant", version="1.0.0")


class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"


@app.get("/health")
def health():
    return {"status": "UP", "service": "ai-assistant", "mcp_connected": bool(JFROG_MCP_URL)}


# VULN-SEED (JAS-Secret): config.py contains a hardcoded OpenAI API key (OPENAI_API_KEY) — JAS detects the sk-proj- prefix pattern automatically — Fix: inject via environment variable OPENAI_API_KEY; never hardcode in source
# VULN-SEED (Curation): config.py references CURSOR_PLUGIN_REGISTRY pointing to an unapproved external marketplace — the Agent Plugins repo policy blocks it at install time — Fix: set CURSOR_PLUGIN_REGISTRY to the internal Artifactory agent-plugins-local repo URL
@app.post("/chat")
async def chat(req: ChatRequest):
    return {
        "session_id": req.session_id,
        "response": (
            f"SwiftShip AI: I can help with your shipping questions. "
            f"You asked: '{req.message}'"
        ),
        "mcp_connected": bool(JFROG_MCP_URL),
    }
