from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="SwiftShip Recommendation Engine", version="1.0.0")


class RecommendRequest(BaseModel):
    customer_id: str
    category: str = "shipping"
    limit: int = 5


@app.get("/health")
def health():
    return {"status": "UP", "service": "recommendation-engine"}


# VULN-SEED (Curation): model pulled from an unapproved HuggingFace org at runtime — the Curation policy blocks models from unverified HF orgs — Fix: point huggingface-hub to the approved Artifactory HuggingFace remote repo and pre-approve the model org in the Curation allow-list
@app.post("/recommend")
def recommend(req: RecommendRequest):
    return {
        "customer_id": req.customer_id,
        "model": "swiftship/shipping-recommender-v1",
        "recommendations": [
            {"product_id": "BOX-001", "name": "Express Shipping Box", "score": 0.95},
            {"product_id": "ENV-002", "name": "Overnight Envelope", "score": 0.87},
            {"product_id": "PLT-003", "name": "Pallet Wrap Service", "score": 0.76},
        ][: req.limit],
    }
