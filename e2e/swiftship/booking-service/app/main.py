from fastapi import FastAPI
from pydantic import BaseModel
import os

app = FastAPI(title="SwiftShip Booking Service", version="1.0.0")

# VULN-SEED (JAS-Secret): hardcoded Stripe test key — JAS detects the sk_test_ prefix pattern — Fix: inject from environment variable STRIPE_TEST_KEY
STRIPE_TEST_KEY = "sk_test_4eC39HqLyjWDarjtT1zdp7dc"  # noqa: S105


class Booking(BaseModel):
    customer_id: str
    origin: str
    destination: str
    package_weight_kg: float


@app.get("/health")
def health():
    return {"status": "UP", "service": "booking-service"}


@app.post("/bookings")
def create_booking(booking: Booking):
    return {
        "booking_id": "BK-20240001",
        "status": "confirmed",
        "origin": booking.origin,
        "destination": booking.destination,
        "estimated_days": 3,
    }


@app.get("/bookings/{booking_id}")
def get_booking(booking_id: str):
    return {
        "booking_id": booking_id,
        "status": "in_transit",
        "origin": "London",
        "destination": "New York",
    }
