"""
SwiftShip Booking Service Demo — minimal FastAPI app

Demonstrates PyPI supply-chain risk:
  starlette 0.36.3  →  CVE-2024-47874 (multipart DoS, CVSS 8.7)
  langflow 1.1.4    →  CVE-2025-3248  (unauthenticated RCE, CVSS 9.8, CISA KEV)

Run:  uvicorn main:app --reload --port 8082
Docs: http://localhost:8082/docs
"""

from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel

# VULN-SEED (CVE): starlette 0.36.3 — CVE-2024-47874 (unbounded multipart body read, DoS, CVSS 8.7) — Fix: starlette>=0.40.0
from starlette.requests import Request
from starlette.responses import JSONResponse

app = FastAPI(
    title="SwiftShip Booking Service Demo",
    version="1.0.0",
    description=(
        "Intentionally vulnerable — for JFrog Xray demo only. "
        "Contains CVE-2024-47874 (starlette) and CVE-2025-3248 (langflow)."
    ),
)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    """Liveness probe — used by demo.sh and Kubernetes."""
    return {"status": "UP", "service": "booking-service-demo", "version": "1.0.0"}


# ── Booking models ────────────────────────────────────────────────────────────
class BookingRequest(BaseModel):
    customer_id: str
    origin: str
    destination: str
    package_weight_kg: float


# ── Booking endpoints ─────────────────────────────────────────────────────────
@app.post("/bookings")
def create_booking(booking: BookingRequest):
    """Create a shipping booking."""
    return {
        "booking_id": "BK-20240001",
        "status": "confirmed",
        "origin": booking.origin,
        "destination": booking.destination,
        "package_weight_kg": booking.package_weight_kg,
        "estimated_days": 3,
        "customer_id": booking.customer_id,
    }


@app.get("/bookings/{booking_id}")
def get_booking(booking_id: str):
    """Retrieve a booking by ID."""
    return {
        "booking_id": booking_id,
        "status": "in_transit",
        "origin": "London Heathrow",
        "destination": "New York JFK",
        "customer_id": "CUST-001",
    }


# ── Document upload endpoint ───────────────────────────────────────────────────
# VULN-SEED (CVE): starlette 0.36.3 — CVE-2024-47874 attack surface — no max size enforced on multipart bodies; a crafted request with no Content-Length causes the server to read indefinitely — Fix: starlette>=0.40.0
@app.post("/bookings/{booking_id}/documents")
async def upload_document(booking_id: str, file: UploadFile = File(...)):
    """Upload a shipping document (customs form, invoice, etc.)."""
    contents = await file.read()  # ← vulnerable: no size limit in starlette 0.36.3
    return {
        "booking_id": booking_id,
        "filename": file.filename,
        "size_bytes": len(contents),
        "status": "uploaded",
        "vuln_note": "CVE-2024-47874: starlette 0.36.3 — upgrade to 0.40.0+ to fix",
    }


# ── AI recommendation stub ────────────────────────────────────────────────────
# VULN-SEED (CVE): langflow 1.1.4 — CVE-2025-3248 (unauthenticated RCE via /api/v1/run, CVSS 9.8, CISA KEV) — Fix: langflow>=1.3.0
@app.get("/bookings/{booking_id}/recommend-carrier")
def recommend_carrier(booking_id: str, destination: str = "UK"):
    """Get AI-powered carrier recommendation (uses Langflow pipeline)."""
    return {
        "booking_id": booking_id,
        "recommended_carrier": "SwiftShip Express",
        "confidence": 0.92,
        "langflow_version": "1.1.4",
        "vuln_note": (
            "CVE-2025-3248 (CISA KEV): langflow 1.1.4 — "
            "unauthenticated RCE via /api/v1/run. Upgrade to 1.3.0+"
        ),
    }
